import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/models/stage_record.dart';
import 'package:navi_app/utils/geo_utils.dart';

class StopProgressResult {
  final int completedStops;
  final int totalStops;
  final String? currentStageName;
  final String? nextStageName;
  final String? previousStageName;
  final bool stageChanged;
  final double progressFraction;

  const StopProgressResult({
    this.completedStops = 0,
    this.totalStops = 0,
    this.currentStageName,
    this.nextStageName,
    this.previousStageName,
    this.stageChanged = false,
    this.progressFraction = 0.0,
  });
}

class StopProgressEngine extends ChangeNotifier {
  final StageDatabase _stageDb = StageDatabase();

  List<String> _routeStopNames = [];
  int _currentStopIndex = 0;
  String? _previousStage;
  final Set<int> _visitedStops = {};
  double _lastCheckLat = 0;
  double _lastCheckLng = 0;

  List<String> get routeStopNames => List.unmodifiable(_routeStopNames);
  int get currentStopIndex => _currentStopIndex;
  int get completedStops => _visitedStops.length;
  int get totalStops => _routeStopNames.length;
  int get remainingStops => totalStops - completedStops;
  double get progressFraction => totalStops > 0 ? completedStops / totalStops : 0;
  String? get currentStageName => _currentStopIndex < _routeStopNames.length
      ? _routeStopNames[_currentStopIndex]
      : null;
  String? get nextStageName => _currentStopIndex + 1 < _routeStopNames.length
      ? _routeStopNames[_currentStopIndex + 1]
      : null;
  bool get isComplete => _currentStopIndex >= _routeStopNames.length;

  Future<void> setRouteStops(List<String> stopNames) async {
    _routeStopNames = stopNames;
    _currentStopIndex = 0;
    _visitedStops.clear();
    _previousStage = null;
    for (final name in stopNames) {
      final results = await _stageDb.searchStages(name);
      if (results.isNotEmpty) {
        cacheStage(name, results.first);
      }
    }
    notifyListeners();
  }

  StopProgressResult checkProgress(double lat, double lng) {
    if (_routeStopNames.isEmpty) {
      return const StopProgressResult();
    }

    bool stageChanged = false;

    for (int i = 0; i < _routeStopNames.length; i++) {
      final distanceToUser = haversineDistance(
        lat, lng,
        _lastCheckLat, _lastCheckLng,
      );

      if (distanceToUser > 10) {
        _lastCheckLat = lat;
        _lastCheckLng = lng;
      }
    }

    final nearestIdx = _findNearestStop(lat, lng);

    if (nearestIdx > _currentStopIndex && !_visitedStops.contains(nearestIdx)) {
      _currentStopIndex = nearestIdx;
      _visitedStops.add(nearestIdx);
      stageChanged = true;

      for (int i = 0; i < nearestIdx; i++) {
        _visitedStops.add(i);
      }
    }

    if (stageChanged) {
      notifyListeners();
    }

    return StopProgressResult(
      completedStops: completedStops,
      totalStops: totalStops,
      currentStageName: _currentStopIndex < _routeStopNames.length
          ? _routeStopNames[_currentStopIndex]
          : _routeStopNames.isNotEmpty
              ? _routeStopNames.last
              : null,
      nextStageName: _currentStopIndex + 1 < _routeStopNames.length
          ? _routeStopNames[_currentStopIndex + 1]
          : null,
      previousStageName: _previousStage,
      stageChanged: stageChanged,
      progressFraction: progressFraction,
    );
  }

  int _findNearestStop(double lat, double lng) {
    int nearestIdx = _currentStopIndex;
    double bestDist = double.infinity;

    for (int i = max(0, _currentStopIndex); i < _routeStopNames.length; i++) {
      final stages = _getCachedStage(_routeStopNames[i]);
      if (stages != null) {
        final dist = haversineDistance(lat, lng, stages.latitude, stages.longitude);
        if (dist < bestDist) {
          bestDist = dist;
          nearestIdx = i;
        }
      }
    }
    return nearestIdx;
  }

  final Map<String, StageRecord> _stageCache = {};

  StageRecord? _getCachedStage(String name) {
    return _stageCache[name];
  }

  void cacheStage(String name, StageRecord stage) {
    _stageCache[name] = stage;
  }

  void reset() {
    _routeStopNames.clear();
    _currentStopIndex = 0;
    _visitedStops.clear();
    _previousStage = null;
    notifyListeners();
  }


}
