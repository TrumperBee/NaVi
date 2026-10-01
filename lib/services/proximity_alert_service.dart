import 'dart:async';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/proximity_threshold.dart';

class ProximityAlertService {
  static final List<ProximityThresholdState> _defaultThresholds = [
    ProximityThresholdState(distance: ProximityDistance.oneKm, meters: 1000),
    ProximityThresholdState(distance: ProximityDistance.fiveHundredM, meters: 500),
    ProximityThresholdState(distance: ProximityDistance.oneHundredM, meters: 100),
    ProximityThresholdState(distance: ProximityDistance.fiftyM, meters: 50),
  ];

  final StreamController<ProximityAlertEvent> _eventController = StreamController<ProximityAlertEvent>.broadcast();

  ProximityTarget? _currentTarget;
  List<ProximityThresholdState> _thresholds = List.from(_defaultThresholds);
  bool _alertsEnabled = true;

  Stream<ProximityAlertEvent> get events => _eventController.stream;
  bool get alertsEnabled => _alertsEnabled;
  ProximityTarget? get currentTarget => _currentTarget;

  set alertsEnabled(bool value) => _alertsEnabled = value;

  ProximityAlertService();

  void resetForNewTarget(ProximityTarget target) {
    _currentTarget = target;
    _thresholds = _defaultThresholds.map((t) => t.copyWith(hasFired: false)).toList();
  }

  void checkProximity(LatLng currentPosition) {
    if (!_alertsEnabled || _currentTarget == null) return;

    final distanceMeters = _haversineDistance(
      currentPosition.latitude,
      currentPosition.longitude,
      _currentTarget!.latitude,
      _currentTarget!.longitude,
    ).round();

    final crossedThresholds = <ProximityThresholdState>[];

    for (final threshold in _thresholds) {
      if (!threshold.hasFired && distanceMeters <= threshold.meters) {
        threshold.hasFired = true;
        crossedThresholds.add(threshold);
      }
    }

    if (crossedThresholds.isEmpty) return;

    if (_currentTarget!.isFinalDestination && crossedThresholds.any((t) => t.distance == ProximityDistance.fiftyM)) {
      _eventController.add(ProximityAlertEvent(
        target: _currentTarget!,
        threshold: ProximityDistance.fiftyM,
        type: ProximityAlertType.arrivalConfirmed,
        remainingMeters: distanceMeters,
      ));
      return;
    }

    final closestCrossed = crossedThresholds.reduce((a, b) => a.meters < b.meters ? a : b);
    _eventController.add(ProximityAlertEvent(
      target: _currentTarget!,
      threshold: closestCrossed.distance,
      type: ProximityAlertType.proximity,
      remainingMeters: distanceMeters,
    ));
  }

  static int _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371000;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLng / 2) * sin(dLng / 2);
    return (2 * atan2(sqrt(a), sqrt(1 - a)) * R).round();
  }

  void dispose() {
    _eventController.close();
  }
}