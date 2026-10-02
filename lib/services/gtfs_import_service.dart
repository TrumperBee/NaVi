import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navi_app/data/nairobi_corridors_seed.dart';
import 'package:navi_app/data/nairobi_stages_seed.dart';
import 'package:navi_app/models/route_record.dart';
import 'package:navi_app/models/stage_record.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/services/database/cache_manager.dart';
import 'package:navi_app/services/stage_registry.dart';

/// One-time import of the bundled GTFS stop/route data into the app's existing
/// local persistence layer (the Hive boxes behind [CacheManager] that
/// `StageDatabase` / `RouteDatabase` already read first).
///
/// Runs once (guarded by the `navi.gtfs.imported_v1` shared-preference flag)
/// during startup, after Hive is initialised and before `runApp`. Nothing new
/// is introduced: stages and routes are parsed into the app's own runtime
/// models (`StageRecord` / `RouteRecord`), written through the existing
/// cache writer, and the synchronous `nairobiStages` consumers are repointed
/// at the imported universe through [StageRegistry].
class GtfsImportService {
  GtfsImportService._();

  static const String stagesAsset = 'assets/data/gtfs_import/stages.json';
  static const String routesAsset = 'assets/data/gtfs_import/routes.json';

  /// Shared-preference flag that makes the import run exactly once.
  static const String importFlagKey = 'navi.gtfs.imported_v1';

  /// Stages that are within this distance of a corridor polyline but carry no
  /// route-number corridor evidence get that corridor assigned geographically.
  static const double _maxSnapMeters = 400.0;

  /// route-name keyword → corridor id. Longer, more specific keywords come
  /// first so e.g. "ngong road" wins over "karen" inside the same name.
  static const Map<String, String> _corridorKeywords = {
    // Ngong Road
    'ngong': 'ngong_road',
    // Lang'ata Road
    "lang'ata": 'langata_road',
    'langata': 'langata_road',
    'ongata rongai': 'langata_road',
    'kiserian': 'langata_road',
    'karen': 'langata_road',
    'bomas': 'langata_road',
    'hardy': 'langata_road',
    // Thika Road
    'thika': 'thika_road',
    'githurai': 'thika_road',
    'roysambu': 'thika_road',
    'kasarani': 'thika_road',
    'ruiru': 'thika_road',
    'mwiki': 'thika_road',
    // Mombasa Road
    'mombasa': 'mombasa_road',
    'mlolongo': 'mombasa_road',
    'kitengela': 'mombasa_road',
    'syokimau': 'mombasa_road',
    'jkia': 'mombasa_road',
    'imara daima': 'mombasa_road',
    'industrial area': 'mombasa_road',
    'athi river': 'mombasa_road',
    'south b': 'mombasa_road',
    'hazina': 'mombasa_road',
    // Jogoo Road / Kangundo Road axis (Kangundo Rd is Jogoo Rd's eastward
    // continuation through Buruburu -> Koma Rock -> Donholm -> Kayole).
    'jogoo': 'jogoo_road',
    'buruburu': 'jogoo_road',
    'makadara': 'jogoo_road',
    'shauri moyo': 'jogoo_road',
    'kangundo': 'jogoo_road',
    'maringo': 'jogoo_road',
    'donholm': 'jogoo_road',
    'kayole': 'jogoo_road',
    'komarocks': 'jogoo_road',
    'njiru': 'jogoo_road',
    'ruai': 'jogoo_road',
    // Outer Ring Road
    'outering': 'outering_road',
    'outer ring': 'outering_road',
    'allsops': 'outering_road',
    // GTFS names misspell Allsops Roundabout as "Alssops"; both variants must
    // resolve to Outer Ring Road.
    'alssops': 'outering_road',
    'saika': 'outering_road',
    // Waiyaki Way / Westlands
    'waiyaki': 'waiyaki_way',
    'westlands': 'waiyaki_way',
    'chiromo': 'waiyaki_way',
    'kangemi': 'waiyaki_way',
    'uthiru': 'waiyaki_way',
    'kinoo': 'waiyaki_way',
    'wangige': 'waiyaki_way',
    'kikuyu': 'waiyaki_way',
    'kabete': 'waiyaki_way',
    'lavington': 'waiyaki_way',
    'kileleshwa': 'waiyaki_way',
  };

  /// Loads the bundled GTFS stages and routes and makes them the app's primary
  /// stage/route source. Returns `true` when an import actually ran, `false`
  /// when it was skipped (already imported, or nothing to do).
  static Future<bool> loadBundledGtfsData({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && prefs.getBool(importFlagKey) == true) {
      print('[GTFS] bundle already imported — skipping');
      return false;
    }

    final result = await parseBundledGtfs();

    // Fail loudly instead of persisting a bundle whose route stage refs do not
    // all resolve. Without this check an id-without-a-stage would silently leak
    // through as its raw id and produce a stage-name mismatch the DB layers
    // match on. When this trips, the previous cache/seed stays in force.
    if (result.unresolvedStageRefs.isNotEmpty) {
      print('[GTFS] REFUSING to import ${result.unresolvedStageRefs.length} '
          'unresolved route stage ref(s): '
          '${result.unresolvedStageRefs.take(10).join(', ')}');
      return false;
    }

    // Persist through the existing Hive cache layer that StageDatabase /
    // RouteDatabase read first — the imported data becomes their primary
    // source while SeedData remains the empty-cache fallback.
    final cache = CacheManager();
    await cache.init();
    await cache.cacheStages(result.stages.map(_toStageModel).toList());
    await cache.cacheRoutes(result.routes.map(_toRouteModel).toList());

    // Repoint synchronous nairobiStages consumers (search, route building) at
    // the imported universe; nairobiStages stays the fallback default.
    StageRegistry.setStages(result.stageData);

    // Report the corridor-assignment breakdown (matched vs unassigned).
    final summary = result.corridorBreakdown.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    print('[GTFS] imported ${result.stages.length} stages '
        '(${result.duplicateStages} duplicate ids skipped) and '
        '${result.routes.length} route records from '
        '${result.routeSourceCount} routes');
    print('[GTFS] corridor assignment: $summary');

    await prefs.setBool(importFlagKey, true);
    return true;
  }

  /// Pure parse of the bundled assets — no Hive, no preferences, no global
  /// state. Exposed so the import can be verified off-device.
  static Future<GtfsImportResult> parseBundledGtfs() async {
    final stagesJson = await rootBundle.loadString(stagesAsset);
    final routesJson = await rootBundle.loadString(routesAsset);

    final stages = <StageRecord>[];
    final idToName = <String, String>{};
    final seenIds = <String>{};
    var duplicateStages = 0;
    for (final raw in jsonDecode(stagesJson) as List) {
      final map = raw as Map<String, dynamic>;
      final stageId = map['stage_id'] as String? ?? '';
      if (stageId.isEmpty || !seenIds.add(stageId)) {
        duplicateStages++;
        continue;
      }
      final stage = StageRecord.fromMap(map, stageId);
      stages.add(stage);
      idToName[stageId] = stage.stageName;
    }

    final rawRoutes = jsonDecode(routesJson) as List;
    final routes = <RouteRecord>[];
    final routeCorridorByNumber = <String, String>{};
    final allOrderedIds = <List<String>>[];
    for (final raw in rawRoutes) {
      final route = raw as Map<String, dynamic>;
      final routeId = route['route_id'] as String? ?? '';
      final routeNumber = route['route_number'] as String? ?? '';
      final routeName = route['route_name'] as String? ?? '';
      final corridor = _inferCorridor(routeName);
      final directions = route['directions'] as List? ?? const [];
      for (final dir in directions) {
        final dirMap = dir as Map<String, dynamic>;
        final directionId = dirMap['direction_id'] as String? ?? '0';
        final orderedIds = (dirMap['ordered_stages'] as List? ?? const [])
            .map((e) => e as String)
            .toList();
        if (orderedIds.isEmpty) continue;
        allOrderedIds.add(orderedIds);
        // Routes reference stage ids; the DB layers match routes to stages by
        // stage NAME, so resolve the ids up front. Unresolved refs are tracked
        // via [findUnresolvedStageRefs] and reject the import at load time, so
        // the raw-id fallback below should never surface in a persisted bundle.
        final orderedNames = orderedIds.map((id) => idToName[id] ?? id).toList();
        routes.add(RouteRecord(
          routeId: '${routeId}_$directionId',
          routeNumber: routeNumber,
          routeName: routeName,
          startStage: orderedNames.first,
          endStage: orderedNames.last,
          orderedStages: orderedNames,
          corridor: corridor,
          sacco: '',
        ));
      }
      routeCorridorByNumber[routeNumber] = corridor;
    }

    final unresolvedStageRefs = findUnresolvedStageRefs(
      stageIds: idToName.keys.toSet(),
      orderedStageIds: allOrderedIds,
    ).toList()
      ..sort();

    final breakdown = <String, int>{};
    for (final route in routes) {
      breakdown[route.corridor] = (breakdown[route.corridor] ?? 0) + 1;
    }

    return GtfsImportResult(
      stages: List.unmodifiable(stages),
      routes: List.unmodifiable(routes),
      stageData: _buildStageData(stages, routeCorridorByNumber),
      duplicateStages: duplicateStages,
      routeSourceCount: rawRoutes.length,
      corridorBreakdown: Map.unmodifiable(breakdown),
      unresolvedStageRefs: List.unmodifiable(unresolvedStageRefs),
    );
  }

  /// Pure check for route stage references that have no matching stage id.
  /// Returns the offending ids (deduplicated). Used at parse time to reject a
  /// bundle whose routes dangle, and testable directly without assets.
  static Set<String> findUnresolvedStageRefs({
    required Set<String> stageIds,
    required List<List<String>> orderedStageIds,
  }) {
    final unresolved = <String>{};
    for (final ordered in orderedStageIds) {
      for (final id in ordered) {
        if (!stageIds.contains(id)) unresolved.add(id);
      }
    }
    return unresolved;
  }

  /// Maps a GTFS stage record onto the StageModel shape the existing Hive
  /// cache stores.
  static StageModel _toStageModel(StageRecord s) {
    return StageModel(
      id: s.stageId,
      name: s.stageName,
      lat: s.latitude,
      lng: s.longitude,
      corridor: s.roadName,
      routes: s.routesServed,
      area: s.area.isEmpty ? null : s.area,
    );
  }

  /// Maps a GTFS route record onto the RouteModel shape the existing Hive
  /// cache stores. Fares are left at 0.0 pending the fare matrix.
  static RouteModel _toRouteModel(RouteRecord r) {
    return RouteModel(
      id: r.routeId,
      name: r.routeName,
      number: r.routeNumber,
      corridor: r.corridor,
      sacco: r.sacco,
      majorStops: r.orderedStages,
    );
  }

  /// Keyword-matches a route name against the corridor set; no match yields
  /// 'unassigned'.
  static String _inferCorridor(String routeName) {
    final lower = routeName.toLowerCase();
    for (final entry in _corridorKeywords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 'unassigned';
  }

  /// Builds the StageData universe the sync consumers use, deriving a
  /// corridor id for each stage:
  ///   1. majority vote over the corridors of the stage's serving routes;
  ///   2. otherwise the nearest corridor polyline within [_maxSnapMeters];
  ///   3. otherwise none (unassigned corridors are the honest answer).
  static List<StageData> _buildStageData(
    List<StageRecord> stages,
    Map<String, String> routeCorridorByNumber,
  ) {
    final routeToCorridor = Map<String, String>.of(routeCorridorByNumber);
    // Classic route numbers from the corridor seed fill gaps the GTFS keyword
    // inference leaves unassigned (e.g. short-hop numbers like "33").
    for (final corridor in nairobiCorridors.values) {
      for (final number in corridor.routeNumbers) {
        routeToCorridor.putIfAbsent(number, () => corridor.id);
      }
    }

    return stages.map((s) {
      final corridorId = _assignCorridorId(s, routeToCorridor);
      return StageData(
        id: s.stageId,
        name: s.stageName,
        lat: s.latitude,
        lng: s.longitude,
        corridorId: corridorId,
        routeNumbers: s.routesServed,
        area: s.area.isEmpty ? null : s.area,
      );
    }).toList();
  }

  static String _assignCorridorId(
    StageRecord stage,
    Map<String, String> routeToCorridor,
  ) {
    final counts = <String, int>{};
    for (final number in stage.routesServed) {
      final corridor = routeToCorridor[number];
      if (corridor != null && corridor != 'unassigned') {
        counts[corridor] = (counts[corridor] ?? 0) + 1;
      }
    }
    if (counts.isNotEmpty) {
      String best = '';
      var bestCount = 0;
      counts.forEach((corridor, count) {
        if (count > bestCount) {
          best = corridor;
          bestCount = count;
        }
      });
      if (best.isNotEmpty) return best;
    }

    return _snapToCorridor(stage.latitude, stage.longitude);
  }

  static String _snapToCorridor(double lat, double lng) {
    String? nearestId;
    var minDistance = double.infinity;
    for (final corridor in nairobiCorridors.values) {
      final distance = _distanceToCorridor(lat, lng, corridor.polyline);
      if (distance < minDistance) {
        minDistance = distance;
        nearestId = corridor.id;
      }
    }
    if (nearestId != null && minDistance <= _maxSnapMeters) return nearestId;
    return '';
  }

  // ==================== GEO HELPERS ====================

  static double _distanceToCorridor(
    double lat,
    double lng,
    List<LatLng> polyline,
  ) {
    if (polyline.length < 2) return double.infinity;
    var minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final distance = _distancePointToSegment(
        lat,
        lng,
        polyline[i].latitude,
        polyline[i].longitude,
        polyline[i + 1].latitude,
        polyline[i + 1].longitude,
      );
      if (distance < minDistance) minDistance = distance;
    }
    return minDistance;
  }

  static double _distancePointToSegment(
    double px,
    double py,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final segmentLength = _haversineDistance(x1, y1, x2, y2);
    if (segmentLength < 1) {
      return _haversineDistance(px, py, x1, y1);
    }

    final dist1 = _haversineDistance(px, py, x1, y1);
    final dist2 = _haversineDistance(px, py, x2, y2);

    final cosTheta1 =
        (dist1 * dist1 + segmentLength * segmentLength - dist2 * dist2) /
            (2 * dist1 * segmentLength);
    final cosTheta2 =
        (dist2 * dist2 + segmentLength * segmentLength - dist1 * dist1) /
            (2 * dist2 * segmentLength);

    if (cosTheta1 < 0) return dist1;
    if (cosTheta2 < 0) return dist2;

    final sinTheta1 = sqrt(max(0.0, 1 - cosTheta1 * cosTheta1));
    return dist1 * sinTheta1;
  }

  static double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double R = 6371000;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLng / 2) * sin(dLng / 2);
    return 2 * atan2(sqrt(a), sqrt(1 - a)) * R;
  }
}

/// Result of parsing the bundled GTFS assets — everything derived from the
/// bundle without touching persistence or global state.
class GtfsImportResult {
  GtfsImportResult({
    required this.stages,
    required this.routes,
    required this.stageData,
    required this.duplicateStages,
    required this.routeSourceCount,
    required this.corridorBreakdown,
    required this.unresolvedStageRefs,
  });

  /// Unique parsed stages (duplicate ids already dropped).
  final List<StageRecord> stages;

  /// Direction-expanded route records.
  final List<RouteRecord> routes;

  /// Ordered stage ids referenced by routes with no matching stage id in the
  /// bundle. Empty for a healthy bundle; a non-empty list rejects the import
  /// at load time (in [GtfsImportService.loadBundledGtfsData]).
  final List<String> unresolvedStageRefs;

  /// [StageData] universe built from the parsed stages (corridor ids derived).
  final List<StageData> stageData;

  /// Stage entries skipped because they duplicated an earlier id.
  final int duplicateStages;

  /// Number of route entries in the bundle (before direction expansion).
  final int routeSourceCount;

  /// route-count per corridor id across all direction records.
  final Map<String, int> corridorBreakdown;
}