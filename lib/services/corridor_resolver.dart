import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/data/nairobi_corridors_seed.dart';
import 'package:navi_app/data/nairobi_stages_seed.dart';
import 'package:navi_app/models/place_record.dart';
import 'package:navi_app/models/search_result.dart';
import 'package:navi_app/services/geocoding_service.dart';
import 'package:navi_app/services/place_registry.dart';
import 'package:navi_app/services/stage_registry.dart';
import 'package:navi_app/utils/string_match.dart';

const double kMaxCorridorSnapMeters = 400.0;

/// Resolves a search query against the indexed local layers in the order the
/// transport data spec §3 mandates: **places first, then stages**, then (in
/// the view-model) community and Mapbox geocoding.
class CorridorResolver {
  static final Map<int, CorridorData> _corridors = nairobiCorridors;

  /// Full stop universe for name/geographic resolution. Reads the runtime
  /// registry: the GTFS universe once imported, the curated seed otherwise.
  static List<StageData> get _allStages => StageRegistry.all;

  static CorridorData? findNearestCorridor(double lat, double lng) {
    CorridorData? nearest;
    double minDistance = double.infinity;

    for (final corridor in _corridors.values) {
      final distance = _distanceToCorridor(lat, lng, corridor.polyline);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = corridor;
      }
    }

    if (nearest != null && minDistance <= kMaxCorridorSnapMeters) {
      return nearest;
    }
    return null;
  }

  static StageData? findNearestStageOnCorridor(String corridorId, double lat, double lng) {
    final corridorStages = _allStages.where((s) => s.corridorId == corridorId).toList();
    if (corridorStages.isEmpty) return null;

    StageData? nearest;
    double minDistance = double.infinity;

    for (final stage in corridorStages) {
      final distance = _haversineDistance(lat, lng, stage.lat, stage.lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = stage;
      }
    }
    return nearest;
  }

  static StageData? findExactStageMatch(String query) {
    final lowerQuery = query.toLowerCase().trim();

    for (final stage in _allStages) {
      final name = stage.name.toLowerCase().trim();

      if (name == lowerQuery) return stage;
      if (name.contains(lowerQuery) || lowerQuery.contains(name)) return stage;

      if (levenshteinDistance(name, lowerQuery) <= kLevenshteinTolerance) {
        return stage;
      }

      final area = stage.area?.toLowerCase().trim() ?? '';
      if (area.isNotEmpty && (area == lowerQuery || area.contains(lowerQuery) || lowerQuery.contains(area))) {
        return stage;
      }
    }
    return null;
  }

  static List<StageData> findStagesByName(String query) {
    final lower = query.toLowerCase().trim();
    return _allStages.where((s) =>
      s.name.toLowerCase().contains(lower) ||
      s.area?.toLowerCase().contains(lower) == true
    ).toList();
  }

  // ==================== PLACES (spec §3 first layer) ====================

  /// Single best place hit for [query], or null. Mirrors stage matching:
  /// case-insensitive, containment in either direction, then fuzzy.
  /// Ambiguous queries are handled by [findPlacesByName], which returns every
  /// match so the UI can present both the place and the stage.
  static PlaceRecord? findExactPlaceMatch(String query) {
    return PlaceRegistry.findByName(query);
  }

  /// Every place matching [query], best match first.
  static List<PlaceRecord> findPlacesByName(String query) {
    return PlaceRegistry.findMatching(query);
  }

  /// Resolves a known [place] into a routable [SearchResult]: corridor snap
  /// then nearest stage on that corridor, exactly the same fallback a Mapbox
  /// POI without a stage name goes through — a place the rider doesn't know
  /// by its bus stop gets boarding context from the nearest stop on the
  /// nearest corridor. No transit nearby yields [SearchResult.noTransitData].
  static SearchResult resolvePlace(PlaceRecord place, {required String query}) {
    final corridor = findNearestCorridor(place.latitude, place.longitude);
    if (corridor == null) {
      return _noTransitPlace(place, query);
    }

    final stage = findNearestStageOnCorridor(
      corridor.id,
      place.latitude,
      place.longitude,
    );
    if (stage == null) {
      return _noTransitPlace(place, query);
    }

    final distance = _haversineDistance(
      place.latitude,
      place.longitude,
      stage.lat,
      stage.lng,
    );

    return SearchResult(
      query: query,
      lat: place.latitude,
      lng: place.longitude,
      resolvedLabel: place.name,
      secondaryLine: null,
      matchedCorridorName: corridor.name,
      nearestStageName: stage.name,
      nearestStageLat: stage.lat,
      nearestStageLng: stage.lng,
      routeNumbers: stage.routeNumbers,
      distanceToStageMeters: distance,
      source: SearchResultSource.localPlace,
    );
  }

  /// A place result that came from the local layer but has no transit nearby
  /// still identifies as a local place (not a Mapbox geocode) so consumers can
  /// tell the layers apart.
  static SearchResult _noTransitPlace(PlaceRecord place, String query) {
    return SearchResult(
      query: query,
      lat: place.latitude,
      lng: place.longitude,
      resolvedLabel: place.name,
      secondaryLine: null,
      matchedCorridorName: null,
      nearestStageName: 'No transit data nearby',
      nearestStageLat: place.latitude,
      nearestStageLng: place.longitude,
      routeNumbers: const [],
      distanceToStageMeters: double.infinity,
      source: SearchResultSource.localPlace,
    );
  }

  static SearchResult resolve(String query, GeocodingResult geocodingResult) {
    // §3 order: the indexed place layer outranks everything — an area or
    // landmark we curate beats a geocoded guess at the same name. A place
    // without corridor linkage is still just that place, so in that case the
    // coordinate path gets a chance to produce a routable entry instead of
    // reporting dead-end "no transit" while Mapbox had transit.
    final exactPlace = findExactPlaceMatch(query);
    if (exactPlace != null &&
        _geocodedNameMatchesPlace(geocodingResult, exactPlace)) {
      final placeResult = resolvePlace(exactPlace, query: query);
      if (placeResult.matchedCorridorName != null) {
        return placeResult;
      }
    }

    return _resolveCoordinate(query, geocodingResult);
  }

  /// Only claim a geocode when it really is the indexed place: "KICC, Nairobi
  /// CBD" belongs to a KICC place, but a "Yaya Centre" hit from a "KICC" query
  /// must resolve on its own merits rather than being relabelled KICC.
  static bool _geocodedNameMatchesPlace(
    GeocodingResult geocodingResult,
    PlaceRecord place,
  ) {
    final geoName = geocodingResult.placeName.toLowerCase();
    final candidates = <String>[
      place.placeId,
      place.name,
      ...place.aliases,
    ];
    for (final candidate in candidates) {
      final target = candidate.toLowerCase().trim();
      if (target.isEmpty) continue;
      if (geoName == target ||
          (target.length >= 3 && geoName.contains(target)) ||
          (geoName.length >= 3 && target.contains(geoName))) {
        return true;
      }
    }
    return false;
  }

  /// Corridor-snap + nearest-stage resolution of an arbitrary coordinate
  /// (exact stage name short-circuits moved to [resolve]).
  static SearchResult _resolveCoordinate(String query, GeocodingResult geocodingResult) {
    final exactStage = findExactStageMatch(query);
    if (exactStage != null) {
      return SearchResult.exactStage(
        query: query,
        stageName: exactStage.name,
        lat: exactStage.lat,
        lng: exactStage.lng,
        routeNumbers: exactStage.routeNumbers,
      );
    }

    final corridor = findNearestCorridor(geocodingResult.coordinate.latitude, geocodingResult.coordinate.longitude);
    if (corridor == null) {
      return SearchResult.noTransitData(
        query: query,
        lat: geocodingResult.coordinate.latitude,
        lng: geocodingResult.coordinate.longitude,
        resolvedLabel: geocodingResult.placeName,
        secondaryLine: geocodingResult.secondaryLine,
      );
    }

    final stage = findNearestStageOnCorridor(
      corridor.id,
      geocodingResult.coordinate.latitude,
      geocodingResult.coordinate.longitude,
    );

    if (stage == null) {
      return SearchResult.noTransitData(
        query: query,
        lat: geocodingResult.coordinate.latitude,
        lng: geocodingResult.coordinate.longitude,
        resolvedLabel: geocodingResult.placeName,
        secondaryLine: geocodingResult.secondaryLine,
      );
    }

    final distance = _haversineDistance(
      geocodingResult.coordinate.latitude,
      geocodingResult.coordinate.longitude,
      stage.lat,
      stage.lng,
    );

    return SearchResult(
      query: query,
      lat: geocodingResult.coordinate.latitude,
      lng: geocodingResult.coordinate.longitude,
      resolvedLabel: geocodingResult.placeName,
      secondaryLine: geocodingResult.secondaryLine,
      matchedCorridorName: corridor.name,
      nearestStageName: stage.name,
      nearestStageLat: stage.lat,
      nearestStageLng: stage.lng,
      routeNumbers: stage.routeNumbers,
      distanceToStageMeters: distance,
      source: SearchResultSource.mapboxGeocode,
    );
  }

  static double _distanceToCorridor(double lat, double lng, List<LatLng> polyline) {
    if (polyline.length < 2) return double.infinity;

    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final distance = _distancePointToSegment(
        lat,
        lng,
        polyline[i].latitude,
        polyline[i].longitude,
        polyline[i + 1].latitude,
        polyline[i + 1].longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }

  static double _distancePointToSegment(
    double px, double py,
    double x1, double y1,
    double x2, double y2,
  ) {
    const double R = 6371000;
    final lat1 = x1 * pi / 180;
    final lat2 = x2 * pi / 180;
    final latP = px * pi / 180;

    final dLat = (x2 - x1) * pi / 180;
    final dLng = (y2 - y1) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final segmentLength = 2 * atan2(sqrt(a), sqrt(1 - a)) * R;

    if (segmentLength < 1) {
      return _haversineDistance(px, py, x1, y1);
    }

    final dLat1 = (px - x1) * pi / 180;
    final dLng1 = (py - y1) * pi / 180;
    final a1 = sin(dLat1 / 2) * sin(dLat1 / 2) +
        cos(lat1) * cos(latP) * sin(dLng1 / 2) * sin(dLng1 / 2);
    final dist1 = 2 * atan2(sqrt(a1), sqrt(1 - a1)) * R;

    final dLat2 = (px - x2) * pi / 180;
    final dLng2 = (py - y2) * pi / 180;
    final a2 = sin(dLat2 / 2) * sin(dLat2 / 2) +
        cos(latP) * cos(lat2) * sin(dLng2 / 2) * sin(dLng2 / 2);
    final dist2 = 2 * atan2(sqrt(a2), sqrt(1 - a2)) * R;

    final cosTheta1 = (dist1 * dist1 + segmentLength * segmentLength - dist2 * dist2) /
        (2 * dist1 * segmentLength);
    final cosTheta2 = (dist2 * dist2 + segmentLength * segmentLength - dist1 * dist1) /
        (2 * dist2 * segmentLength);

    if (cosTheta1 < 0) return dist1;
    if (cosTheta2 < 0) return dist2;

    final sinTheta1 = sqrt(max(0.0, 1 - cosTheta1 * cosTheta1));
    return dist1 * sinTheta1;
  }

  static double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371000;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLng / 2) * sin(dLng / 2);
    return 2 * atan2(sqrt(a), sqrt(1 - a)) * R;
  }
}