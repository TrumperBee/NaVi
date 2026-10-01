import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:navi_app/utils/geo_utils.dart';

class AlightDetectionResult {
  final bool isApproaching;
  final bool hasAlighted;
  final double approachConfidence;
  final double distanceToStop;
  final double speedDropRatio;

  const AlightDetectionResult({
    this.isApproaching = false,
    this.hasAlighted = false,
    this.approachConfidence = 0.0,
    this.distanceToStop = double.infinity,
    this.speedDropRatio = 1.0,
  });
}

class AlightDetectionEngine extends ChangeNotifier {
  double _destinationLat = 0;
  double _destinationLng = 0;
  final List<double> _recentSpeeds = [];
  static const int _speedWindow = 10;

  bool _approachingTriggered = false;
  bool _alightTriggered = false;

  void setDestination(double lat, double lng) {
    _destinationLat = lat;
    _destinationLng = lng;
    _approachingTriggered = false;
    _alightTriggered = false;
    _recentSpeeds.clear();
  }

  AlightDetectionResult analyze(double lat, double lng, double speed) {
    _recentSpeeds.add(speed);
    if (_recentSpeeds.length > _speedWindow) {
      _recentSpeeds.removeAt(0);
    }

    final distance = haversineDistance(lat, lng, _destinationLat, _destinationLng);
    final speedDrop = _calculateSpeedDropRatio();

    final isApproaching = _detectApproach(distance, speed);
    final hasAlighted = _detectAlight(distance, speed, speedDrop);

    final confidence = _calculateConfidence(distance, speedDrop);

    notifyListeners();

    return AlightDetectionResult(
      isApproaching: isApproaching,
      hasAlighted: hasAlighted,
      approachConfidence: confidence,
      distanceToStop: distance,
      speedDropRatio: speedDrop,
    );
  }

  bool _detectApproach(double distance, double speed) {
    if (_approachingTriggered) return false;

    if (distance < 500 && speed > 1.0) {
      _approachingTriggered = true;
      return true;
    }
    return false;
  }

  bool _detectAlight(double distance, double speed, double speedDrop) {
    if (_alightTriggered) return false;
    if (!_approachingTriggered) return false;

    if (distance < 100 && speed < 0.5 && speedDrop < 0.3) {
      _alightTriggered = true;
      return true;
    }
    return false;
  }

  double _calculateSpeedDropRatio() {
    if (_recentSpeeds.length < 4) return 1.0;

    final recent = _recentSpeeds.sublist(_recentSpeeds.length - 4);
    final recentAvg = recent.fold(0.0, (s, v) => s + v) / recent.length;

    final older = _recentSpeeds.sublist(0, min(4, _recentSpeeds.length ~/ 2));
    final olderAvg = older.fold(0.0, (s, v) => s + v) / older.length;

    if (olderAvg <= 0) return 1.0;
    return recentAvg / olderAvg;
  }

  double _calculateConfidence(double distance, double speedDrop) {
    double confidence = 0.0;

    if (distance < 500) confidence += 0.3;
    if (distance < 200) confidence += 0.3;
    if (distance < 100) confidence += 0.2;

    if (speedDrop < 0.5) confidence += 0.2;
    if (speedDrop < 0.3) confidence += 0.3;

    return confidence.clamp(0.0, 1.0);
  }

  void reset() {
    _approachingTriggered = false;
    _alightTriggered = false;
    _recentSpeeds.clear();
    notifyListeners();
  }


}
