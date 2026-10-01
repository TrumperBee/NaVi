import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/models/route_record.dart';
import 'package:navi_app/models/stage_record.dart';
import 'package:navi_app/utils/geo_utils.dart';

class RouteMatchResult {
  final RouteRecord route;
  final double confidence;
  final double matchPercentage;
  final double deviation;
  final String? currentStageName;
  final String? nextStageName;
  final int currentStopIndex;
  final bool isOnRoute;

  const RouteMatchResult({
    required this.route,
    required this.confidence,
    required this.matchPercentage,
    this.deviation = 0.0,
    this.currentStageName,
    this.nextStageName,
    this.currentStopIndex = 0,
    this.isOnRoute = false,
  });
}

class RouteMatcherEngine extends ChangeNotifier {
  final StageDatabase _stageDb = StageDatabase();

  RouteMatchResult? _currentMatch;
  final List<LatLng> _userPath = [];

  RouteMatchResult? get currentMatch => _currentMatch;
  List<LatLng> get userPath => List.unmodifiable(_userPath);

  void recordPoint(double lat, double lng) {
    _userPath.add(LatLng(lat, lng));
    if (_userPath.length > 50) {
      _userPath.removeAt(0);
    }
  }

  Future<RouteMatchResult?> matchToRoutes(List<RouteRecord> candidateRoutes) async {
    if (_userPath.length < 3) return null;

    RouteMatchResult? bestMatch;
    double bestScore = 0;

    for (final route in candidateRoutes) {
      final routeStages = await _getRouteStages(route);
      if (routeStages.isEmpty) continue;

      final score = _calculateMatchScore(routeStages);
      if (score > bestScore) {
        bestScore = score;
        final currentIdx = _findCurrentStopIndex(routeStages);
        bestMatch = RouteMatchResult(
          route: route,
          confidence: score,
          matchPercentage: score * 100,
          deviation: 1.0 - score,
          currentStageName: currentIdx >= 0 && currentIdx < routeStages.length
              ? routeStages[currentIdx].stageName
              : null,
          nextStageName: currentIdx + 1 < routeStages.length
              ? routeStages[currentIdx + 1].stageName
              : null,
          currentStopIndex: currentIdx,
          isOnRoute: score > 0.3,
        );
      }
    }

    _currentMatch = bestMatch;
    notifyListeners();
    return bestMatch;
  }

  double _calculateMatchScore(List<StageRecord> routeStages) {
    if (_userPath.isEmpty || routeStages.isEmpty) return 0;

    double proximityScore = 0;
    int closePoints = 0;

    for (final point in _userPath) {
      double minDist = double.infinity;
      for (final stage in routeStages) {
        final dist = haversineDistance(
          point.latitude, point.longitude,
          stage.latitude, stage.longitude,
        );
        if (dist < minDist) minDist = dist;
      }

      if (minDist < 500) {
        proximityScore += 1.0 - (minDist / 500);
        closePoints++;
      }
    }

    final directionScore = _checkDirection(routeStages);
    final coverageScore = _userPath.length > 0 ? closePoints / _userPath.length : 0;

    return (proximityScore / max(1, _userPath.length)) * 0.5 +
        directionScore * 0.3 +
        coverageScore * 0.2;
  }

  double _checkDirection(List<StageRecord> routeStages) {
    if (_userPath.length < 2 || routeStages.length < 2) return 0;

    final firstPoint = _userPath.first;
    final lastPoint = _userPath.last;
    final userBearing = bearing(
      firstPoint.latitude, firstPoint.longitude,
      lastPoint.latitude, lastPoint.longitude,
    );

    int closeCount = 0;
    for (int i = 0; i < routeStages.length - 1; i++) {
      final stageBearing = bearing(
        routeStages[i].latitude, routeStages[i].longitude,
        routeStages[i + 1].latitude, routeStages[i + 1].longitude,
      );
      final diff = (userBearing - stageBearing).abs() % 360;
      if (diff < 45 || diff > 315) closeCount++;
    }

    return routeStages.length > 1 ? closeCount / (routeStages.length - 1) : 0;
  }

  int _findCurrentStopIndex(List<StageRecord> routeStages) {
    if (_userPath.isEmpty) return 0;

    final lastPoint = _userPath.last;
    int bestIdx = 0;
    double bestDist = double.infinity;

    for (int i = 0; i < routeStages.length; i++) {
      final dist = haversineDistance(
        lastPoint.latitude, lastPoint.longitude,
        routeStages[i].latitude, routeStages[i].longitude,
      );
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }

    return bestIdx;
  }

  bool isDeviating() {
    if (_currentMatch == null) return false;
    return _currentMatch!.deviation > 0.7;
  }

  void reset() {
    _userPath.clear();
    _currentMatch = null;
    notifyListeners();
  }

  Future<List<StageRecord>> _getRouteStages(RouteRecord route) async {
    final stages = <StageRecord>[];
    for (final stageName in route.orderedStages) {
      final results = await _stageDb.searchStages(stageName);
      if (results.isNotEmpty) {
        stages.add(results.first);
      }
    }
    return stages;
  }


}
