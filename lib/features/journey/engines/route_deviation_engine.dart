import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/utils/geo_utils.dart';

enum DeviationType {
  none,
  wrongRoute,
  missedStop,
  wrongDirection,
  offRoute,
}

class DeviationResult {
  final DeviationType type;
  final double confidence;
  final String? message;
  final String? suggestedRouteNumber;
  final bool needsRerouting;

  const DeviationResult({
    this.type = DeviationType.none,
    this.confidence = 0.0,
    this.message,
    this.suggestedRouteNumber,
    this.needsRerouting = false,
  });
}

class RouteDeviationEngine extends ChangeNotifier {
  final List<LatLng> _expectedPath = [];
  final List<LatLng> _userPath = [];
  double _maxAllowedDeviation = 500;

  double _destinationLat = 0;
  double _destinationLng = 0;
  double _startLat = 0;
  double _startLng = 0;

  DeviationResult? _lastDeviation;

  DeviationResult? get lastDeviation => _lastDeviation;

  void configure({
    required List<LatLng> expectedPath,
    double maxDeviationMeters = 500,
  }) {
    _expectedPath.clear();
    _expectedPath.addAll(expectedPath);
    _maxAllowedDeviation = maxDeviationMeters;
  }

  void setJourneyBounds(double startLat, double startLng, double destLat, double destLng) {
    _startLat = startLat;
    _startLng = startLng;
    _destinationLat = destLat;
    _destinationLng = destLng;
  }

  void recordUserPoint(double lat, double lng) {
    _userPath.add(LatLng(lat, lng));
    if (_userPath.length > 30) {
      _userPath.removeAt(0);
    }
  }

  DeviationResult analyze(double lat, double lng) {
    _lastDeviation = _checkDeviations(lat, lng);
    return _lastDeviation!;
  }

  DeviationResult _checkDeviations(double lat, double lng) {
    if (_expectedPath.isEmpty && _userPath.length < 3) {
      return const DeviationResult();
    }

    final wrongDirResult = _checkWrongDirection(lat, lng);
    if (wrongDirResult.type != DeviationType.none) return wrongDirResult;

    final offRouteResult = _checkOffRoute(lat, lng);
    if (offRouteResult.type != DeviationType.none) return offRouteResult;

    return const DeviationResult();
  }

  DeviationResult _checkWrongDirection(double lat, double lng) {
    if (_userPath.length < 3) return const DeviationResult();

    final currentBearing = bearing(
      _userPath.first.latitude, _userPath.first.longitude,
      lat, lng,
    );
    final expectedBearing = bearing(
      _startLat, _startLng,
      _destinationLat, _destinationLng,
    );

    final diff = (currentBearing - expectedBearing).abs() % 360;
    if (diff > 135 && diff < 225) {
      return DeviationResult(
        type: DeviationType.wrongDirection,
        confidence: 0.7,
        message: 'You appear to be heading away from your destination',
        needsRerouting: true,
      );
    }

    return const DeviationResult();
  }

  DeviationResult _checkOffRoute(double lat, double lng) {
    if (_expectedPath.isEmpty) return const DeviationResult();

    double minDist = double.infinity;
    for (final pathPoint in _expectedPath) {
      final dist = haversineDistance(
        lat, lng,
        pathPoint.latitude, pathPoint.longitude,
      );
      if (dist < minDist) minDist = dist;
    }

    if (minDist > _maxAllowedDeviation) {
      return DeviationResult(
        type: DeviationType.offRoute,
        confidence: ((minDist - _maxAllowedDeviation) / 1000).clamp(0.0, 1.0),
        message: 'You appear to have left the route',
        needsRerouting: true,
      );
    }

    return const DeviationResult();
  }

  void reset() {
    _expectedPath.clear();
    _userPath.clear();
    _lastDeviation = null;
    notifyListeners();
  }


}
