import 'package:flutter/foundation.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/models/stage_record.dart';
import 'package:navi_app/utils/geo_utils.dart';

enum GeofenceEvent { entered, exited, approaching }

class GeofenceResult {
  final StageRecord stage;
  final GeofenceEvent event;
  final double distance;

  const GeofenceResult({
    required this.stage,
    required this.event,
    required this.distance,
  });
}

class StageGeofenceEngine extends ChangeNotifier {
  final StageDatabase _stageDb = StageDatabase();
  final Set<String> _activeStages = {};
  bool _isChecking = false;

  double _approachRadius = 200;
  double _entryRadius = 50;
  double _exitRadius = 100;

  List<GeofenceResult> _recentEvents = [];

  double get approachRadius => _approachRadius;
  double get entryRadius => _entryRadius;
  double get exitRadius => _exitRadius;
  List<GeofenceResult> get recentEvents => List.unmodifiable(_recentEvents);

  Set<String> get activeStages => Set.unmodifiable(_activeStages);

  void configureRadii({double approach = 200, double entry = 50, double exit = 100}) {
    _approachRadius = approach;
    _entryRadius = entry;
    _exitRadius = exit;
  }

  Future<List<GeofenceResult>> checkGeofences(double lat, double lng) async {
    if (_isChecking) return [];
    _isChecking = true;
    try {
      final events = <GeofenceResult>[];
      final nearby = await _stageDb.findNearbyStages(
        latitude: lat,
        longitude: lng,
        radiusMeters: _approachRadius,
        maxResults: 10,
      );

      final nearbyIds = <String>{};
      for (final stage in nearby) {
        nearbyIds.add(stage.stageId);
        final distance = haversineDistance(lat, lng, stage.latitude, stage.longitude);

        if (distance <= _entryRadius) {
          if (!_activeStages.contains(stage.stageId)) {
            _activeStages.add(stage.stageId);
            events.add(GeofenceResult(
              stage: stage,
              event: GeofenceEvent.entered,
              distance: distance,
            ));
          }
        } else if (distance <= _approachRadius) {
          events.add(GeofenceResult(
            stage: stage,
            event: GeofenceEvent.approaching,
            distance: distance,
          ));
        }
      }

      for (final stageId in _activeStages.toList()) {
        if (!nearbyIds.contains(stageId)) {
          _activeStages.remove(stageId);
        }
      }

      if (events.isNotEmpty) {
        _recentEvents.addAll(events);
        if (_recentEvents.length > 20) {
          _recentEvents = _recentEvents.sublist(_recentEvents.length - 20);
        }
        notifyListeners();
      }

      return events;
    } finally {
      _isChecking = false;
    }
  }

  bool isAtStage(String stageId) => _activeStages.contains(stageId);

  bool isAtStageName(String stageName) {
    return false;
  }

  String? getCurrentStageName() {
    return null;
  }

  void clearState() {
    _activeStages.clear();
    _recentEvents.clear();
  }


}
