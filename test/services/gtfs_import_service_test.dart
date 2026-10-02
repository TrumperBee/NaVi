import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:navi_app/data/nairobi_stages_seed.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/models/search_result.dart';
import 'package:navi_app/services/corridor_resolver.dart';
import 'package:navi_app/services/database/cache_manager.dart';
import 'package:navi_app/services/gtfs_import_service.dart';
import 'package:navi_app/services/route_builder_service.dart';
import 'package:navi_app/services/stage_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String sumMap(Map<String, int> map) {
    return map.entries.map((e) => '${e.key}=${e.value}').join(', ');
  }

  group('GtfsImportService.parseBundledGtfs', () {
    late GtfsImportResult result;

    setUpAll(() async {
      result = await GtfsImportService.parseBundledGtfs();
    });

    test('parses every bundled stage, deduping the two duplicate ids', () {
      // stages.json holds 2,773 entries; riverside_2 and umoja_2 each appear
      // twice, so the unique universe is 2,771.
      expect(result.stages.length, 2771);
      expect(result.duplicateStages, 2);
      final byId = <String, int>{};
      for (final s in result.stages) {
        byId[s.stageId] = (byId[s.stageId] ?? 0) + 1;
      }
      expect(byId.values.every((count) => count == 1), isTrue);
    });

    test('expands routes into per-direction records with names resolved', () {
      expect(result.routes.length, 271);
      expect(result.routeSourceCount, 136);
      final idToName = {for (final s in result.stages) s.stageId: s.stageName};
      for (final r in result.routes) {
        expect(idToName.containsKey(r.startStage) ||
            r.routeName.isNotEmpty, isTrue);
        // Every ordered stage must have resolved to a real stage NAME from
        // the bundle (no raw ids leaking through).
        for (final stage in r.orderedStages) {
          expect(idToName.values.contains(stage), isTrue,
              reason: 'unresolved ordered stage: $stage '
                  '(route ${r.routeNumber})');
        }
        expect(r.orderedStages.length, greaterThanOrEqualTo(2));
        expect(r.startStage, r.orderedStages.first);
        expect(r.endStage, r.orderedStages.last);
        expect(r.routeId, endsWith(r.routeId.split('_').last));
      }
    });

    test('corridor assignment covers every record and reports unassigned', () {
      final total = result.corridorBreakdown.values.fold<int>(0, (a, b) => a + b);
      expect(total, result.routes.length);
      expect(result.corridorBreakdown.containsKey('unassigned'), isTrue);
      final assigned = result.corridorBreakdown.entries
          .where((e) => e.key != 'unassigned')
          .map((e) => '${e.key}=${e.value}')
          .join(', ');
      // ignore: avoid_print (diagnostic evidence)
      print('[GTFS:test] corridor assignment -> '
          '${sumMap(result.corridorBreakdown)}');
      print('[GTFS:test] assigned (excl unassigned) -> ($assigned) '
          'unassigned=${result.corridorBreakdown['unassigned']}');
    });

    test('TASK2: no dangling stage refs; dedup ids keep their first name', () {
      // riverside_2 and umoja_2 each appear twice in the bundle. The second
      // entry is dropped (keep-first), but the id survives, so routes that
      // reference them still resolve to the first occurrence's name.
      expect(result.unresolvedStageRefs, isEmpty,
          reason: 'an id without a stage would leak a raw id into route names');
      final idToName = {for (final s in result.stages) s.stageId: s.stageName};
      for (final id in ['riverside_2', 'umoja_2']) {
        expect(idToName.containsKey(id), isTrue, reason: '$id must survive');
      }
      final allNames = idToName.values.toSet();
      for (final r in result.routes) {
        for (final stage in r.orderedStages) {
          expect(allNames.contains(stage), isTrue,
              reason: 'route ${r.routeNumber} leaks $stage (raw id?)');
        }
      }
      expect(idToName['riverside_2'], isNot('riverside_2'));
      expect(idToName['umoja_2'], isNot('umoja_2'));
    });

    test('TASK2: findUnresolvedStageRefs proves it catches broken refs', () {
      final healthy = GtfsImportService.findUnresolvedStageRefs(
        stageIds: {'riverside_2', 'umoja_2', 'kencom_1'},
        orderedStageIds: [
          ['kencom_1', 'riverside_2'],
          ['riverside_2', 'umoja_2'],
        ],
      );
      expect(healthy, isEmpty);

      final broken = GtfsImportService.findUnresolvedStageRefs(
        stageIds: {'kencom_1'},
        orderedStageIds: [
          ['kencom_1', 'riverside_2'],
          ['riverside_2', 'ghost_stage_id', 'umoja_2'],
        ],
      );
      expect(broken, {'riverside_2', 'ghost_stage_id', 'umoja_2'});
    });

    test('TASK4: unassigned corridor routes logged for review', () {
      final unassigned =
          result.routes.where((r) => r.corridor == 'unassigned').toList();
      expect(unassigned, isNotEmpty);
      final seen = <String>{};
      for (final r in unassigned) {
        if (seen.add('${r.routeNumber}|${r.routeName}')) {
          // ignore: avoid_print (diagnostic evidence)
          print('[GTFS:test] unassigned -> ${r.routeNumber} | ${r.routeName} | '
              '${r.startStage} -> ${r.endStage}');
        }
      }
      print('[GTFS:test] unassigned direction records: ${unassigned.length}, '
          'unique route numbers: ${seen.length}');
    });

    // Both routes live in corridors the app does not model, so their stages
    // carry corridorId '' and RouteBuilderService falls into the
    // _buildDirectStageRide path (straight great-circle ride between the two
    // stage coords) instead of a corridor-polyline slice. These prove that
    // fallback emits sane, non-zero journeys for real unassigned routes.
    test('TASK4: unassigned route 114R (Limuru->Ngara) builds a sane '
        'direct-stage journey', () async {
      StageRegistry.setStages(result.stageData);
      addTearDown(() => StageRegistry.setStages(nairobiStages));

      final route = result.routes.firstWhere((r) =>
          r.routeNumber == '114R' && r.startStage == 'Limuru Terminus');
      final start = StageRegistry.all.firstWhere((s) => s.name == route.startStage);
      final end = StageRegistry.all.firstWhere((s) => s.name == route.endStage);
      expect(start.corridorId, isEmpty,
          reason: 'Limuru terminus must be outside all modeled corridors '
              'so the direct-stage guard engages');

      final journey = await RouteBuilderService.build(
        origin: start.location,
        destination: SearchResult.exactStage(
          query: end.name,
          stageName: end.name,
          lat: end.location.latitude,
          lng: end.location.longitude,
          routeNumbers: end.routeNumbers,
        ),
      );

      expect(journey.segments, isNotEmpty);
      for (final segment in journey.segments) {
        expect(segment.distanceMeters, greaterThan(0.0),
            reason: '${segment.label} must be rideable');
        expect(segment.estimatedDuration, greaterThan(Duration.zero),
            reason: '${segment.label} must not be zero-length');
      }
      expect(journey.totalDistanceMeters, greaterThan(0.0));
      expect(journey.totalEstimatedDuration, greaterThan(Duration.zero));
      expect(journey.fareTotalKsh, greaterThan(0));

      final ride = journey.segments
          .firstWhere((s) => s.mode == SegmentMode.matatu);
      expect(ride.label, startsWith('Ride Route '));
      expect(ride.label, endsWith(end.name));
      // ignore: avoid_print (diagnostic evidence)
      print('[GTFS:test] 114R Limuru->Ngara -> ${journey.segments.map((s) => '${s.label} '
          '[${s.distanceMeters.round()}m, ~${s.estimatedDuration.inMinutes}min]').join(' | ')}');
    });

    test('TASK4: unassigned route 100 (Kiambu->OTC) builds a sane direct-stage '
        'journey', () async {
      StageRegistry.setStages(result.stageData);
      addTearDown(() => StageRegistry.setStages(nairobiStages));

      final route = result.routes.firstWhere((r) =>
          r.routeNumber == '100' && r.startStage == 'Kiambu Bus Terminus');
      final start = StageRegistry.all.firstWhere((s) => s.name == route.startStage);
      final end = StageRegistry.all.firstWhere((s) => s.name == route.endStage);
      expect(start.corridorId, isEmpty,
          reason: 'Kiambu terminus must be outside all modeled corridors '
              'so the direct-stage guard engages');

      final journey = await RouteBuilderService.build(
        origin: start.location,
        destination: SearchResult.exactStage(
          query: end.name,
          stageName: end.name,
          lat: end.location.latitude,
          lng: end.location.longitude,
          routeNumbers: end.routeNumbers,
        ),
      );

      expect(journey.segments, isNotEmpty);
      for (final segment in journey.segments) {
        expect(segment.distanceMeters, greaterThan(0.0));
        expect(segment.estimatedDuration, greaterThan(Duration.zero));
      }
      final ride = journey.segments
          .firstWhere((s) => s.mode == SegmentMode.matatu);
      expect(ride.label, startsWith('Ride Route '));
      expect(ride.label, endsWith(end.name));
      // ignore: avoid_print (diagnostic evidence)
      print('[GTFS:test] 100 Kiambu->OTC -> ${journey.segments.map((s) => '${s.label} '
          '[${s.distanceMeters.round()}m, ~${s.estimatedDuration.inMinutes}min]').join(' | ')}');
    });

    test('stageData mirrors the stage universe and search resolves via the '
        'same CorridorResolver path Home search uses', () async {
      expect(result.stageData.length, 2771);
      StageRegistry.setStages(result.stageData);
      addTearDown(() => StageRegistry.setStages(nairobiStages));

      final agip = CorridorResolver.findStagesByName('Agip');
      expect(agip, isNotEmpty,
          reason: 'GTFS contains agip / agip-olympic stages');

      final ngara = CorridorResolver.findStagesByName('Ngara');
      expect(ngara, isNotEmpty,
          reason: 'GTFS contains ngara_1 "Ngara" stages');

      // A smoke end-to-end: route builder must not throw for a real GTFS pair.
      final north = CorridorResolver.findStagesByName('Kencom').first;
      final south = CorridorResolver.findStagesByName('Imara Daima').first;
      final journey = await RouteBuilderService.build(
        origin: north.location,
        destination: SearchResult.exactStage(
          query: south.name,
          stageName: south.name,
          lat: south.location.latitude,
          lng: south.location.longitude,
          routeNumbers: south.routeNumbers,
        ),
      );
      expect(journey.segments, isNotEmpty);
      // ignore: avoid_print (diagnostic evidence)
      print('[GTFS:test] Kencom->Imara Daima journey segments: '
          '${journey.segments.map((s) => s.label).join(' | ')}');
    });
  });

  group('boot flow (main.dart import sequence, Hive to temp dir)', () {
    late Directory dir;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('navi_gtfs_test');
      Hive.init(dir.path);
      // Reuse one CacheManager across the "two launches".
      final cache = CacheManager();
      await cache.init();
    });

    tearDownAll(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('first launch imports once, persists, and relaunch skips', () async {
      // First "launch" mirrors main.dart: parse -> Hive cache -> registry.
      final first = await GtfsImportService.loadBundledGtfsData();
      expect(first, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(GtfsImportService.importFlagKey), isTrue);

      // Registry now serves the GTFS universe.
      expect(StageRegistry.all.length, 2771);
      addTearDown(() => StageRegistry.setStages(nairobiStages));

      // The Hive cache exactly matches what StageDatabase/RouteDatabase read
      // first (getCachedStages/getCachedRoutes).
      final cache = CacheManager();
      final cachedStages = cache.getCachedStages();
      final cachedRoutes = cache.getCachedRoutes();
      expect(cachedStages, isNotNull);
      expect(cachedStages!.length, 2771);
      expect(cachedRoutes, isNotNull);
      expect(cachedRoutes!.length, 271);

      // Agip/Ngara resolve through the cache-backed registrar path.
      expect(corridorStageCount('Agip'), greaterThan(0));
      expect(corridorStageCount('Ngara'), greaterThan(0));

      // Second "launch" = relaunch skip via the flag.
      final second = await GtfsImportService.loadBundledGtfsData();
      expect(second, isFalse);
    });
  });
}

int corridorStageCount(String query) {
  return StageRegistry.all
      .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
      .length;
}