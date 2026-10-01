import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/data/nairobi_corridors_seed.dart';
import 'package:navi_app/data/nairobi_stages_seed.dart';
import 'package:navi_app/models/search_result.dart';
import 'package:navi_app/services/geocoding_service.dart';

const double kMaxCorridorSnapMeters = 400.0;
const double kFuzzyMatchThreshold = 0.85;
const int kLevenshteinTolerance = 2;

class CorridorResolver {
  static final Map<int, CorridorData> _corridors = nairobiCorridors;
  static final List<StageData> _allStages = nairobiStages;

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

      if (_levenshteinDistance(name, lowerQuery) <= kLevenshteinTolerance) {
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

  static SearchResult resolve(String query, GeocodingResult geocodingResult) {
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

  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;
    final dp = List.generate(len1 + 1, (_) => List<int>.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) dp[i][0] = i;
    for (int j = 0; j <= len2; j++) dp[0][j] = j;

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        dp[i][j] = min(
          dp[i - 1][j] + 1,
          min(dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost),
        );
      }
    }
    return dp[len1][len2];
  }
}