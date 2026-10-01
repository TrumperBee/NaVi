import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/services/navigation_service.dart';
import 'package:navi_app/utils/distance_formatter.dart';

class JourneyTrackingEngine {
  final NavigationService _navigationService = NavigationService();

  StreamSubscription<Object?>? _trackingSubscription;

  bool _isTracking = false;
  LatLng? _currentPosition;
  double _distanceTraveled = 0;
  int _elapsedSeconds = 0;
  Timer? _timer;

  bool get isTracking => _isTracking;
  double get distanceTraveled => _distanceTraveled;
  int get elapsedSeconds => _elapsedSeconds;

  String get formattedDuration {
    if (_elapsedSeconds < 60) return '$_elapsedSeconds sec';
    final minutes = (_elapsedSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = (minutes / 60).floor();
    final remainingMins = minutes % 60;
    return '${hours}h ${remainingMins}m';
  }

  String get formattedDistance =>
      DistanceFormatter.format(_distanceTraveled);

  void startTracking(LatLng startPosition) {
    _currentPosition = startPosition;
    _distanceTraveled = 0;
    _elapsedSeconds = 0;
    _isTracking = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
    });
  }

  void updatePosition(LatLng newPosition) {
    if (!_isTracking || _currentPosition == null) return;

    final distance = _navigationService.calculateDistance(
      _currentPosition!,
      newPosition,
    );

    _distanceTraveled += distance;
    _currentPosition = newPosition;
  }

  Map<String, dynamic> stopTracking() {
    _timer?.cancel();
    _isTracking = false;

    final summary = {
      'distance': _distanceTraveled,
      'duration': _elapsedSeconds,
      'formatted_distance': formattedDistance,
      'formatted_duration': formattedDuration,
    };

    return summary;
  }

  void reset() {
    _timer?.cancel();
    _isTracking = false;
    _currentPosition = null;
    _distanceTraveled = 0;
    _elapsedSeconds = 0;
  }

  void dispose() {
    _timer?.cancel();
    _trackingSubscription?.cancel();
  }
}
