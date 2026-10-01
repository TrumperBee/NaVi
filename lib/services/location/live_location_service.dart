import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:navi_app/services/database/local_storage_service.dart';
import 'package:navi_app/utils/geo_utils.dart';

class LocationSample {
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final double accuracy;
  final DateTime timestamp;

  LocationSample({
    required this.latitude,
    required this.longitude,
    this.speed = 0,
    this.heading = 0,
    this.accuracy = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum TrackingMode {
  idle,
  lowPower,
  mediumPower,
  highAccuracy,
}

class LiveLocationService {
  static final LiveLocationService _instance = LiveLocationService._internal();
  factory LiveLocationService() => _instance;
  LiveLocationService._internal();

  final LocalStorageService _storage = LocalStorageService();

  LocationSample? _lastSample;
  LocationSample? _previousSample;
  List<LocationSample> _recentSamples = [];
  StreamSubscription<Position>? _positionSubscription;

  TrackingMode _trackingMode = TrackingMode.idle;
  bool _isTracking = false;
  int _sampleCount = 0;

  final List<void Function(LocationSample)> _locationListeners = [];
  final List<void Function(TrackingMode)> _modeChangeListeners = [];

  LocationSample? get lastSample => _lastSample;
  LocationSample? get previousSample => _previousSample;
  List<LocationSample> get recentSamples => List.unmodifiable(_recentSamples);
  TrackingMode get trackingMode => _trackingMode;
  bool get isTracking => _isTracking;

  double get currentSpeed => _lastSample?.speed ?? 0;
  double get currentHeading => _lastSample?.heading ?? 0;
  double? get currentLatitude => _lastSample?.latitude;
  double? get currentLongitude => _lastSample?.longitude;

  double get averageSpeed {
    if (_recentSamples.length < 2) return 0;
    return _recentSamples.fold(0.0, (sum, s) => sum + s.speed) / _recentSamples.length;
  }

  double get maxRecentSpeed {
    if (_recentSamples.isEmpty) return 0;
    return _recentSamples.map((s) => s.speed).reduce(max);
  }

  bool get isWalking => currentSpeed < 1.67 && averageSpeed < 1.67;
  bool get isStationary => currentSpeed < 0.5;
  bool get isInVehicle => currentSpeed > 3.33;

  double get distanceTraveled {
    if (_recentSamples.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < _recentSamples.length; i++) {
      total += haversineDistance(
        _recentSamples[i - 1].latitude, _recentSamples[i - 1].longitude,
        _recentSamples[i].latitude, _recentSamples[i].longitude,
      );
    }
    return total;
  }

  Future<void> setBackgroundTracking(bool enabled) async {
    await _storage.setSetting('background_tracking', enabled);
  }

  void onLocation(void Function(LocationSample) callback) {
    _locationListeners.add(callback);
  }

  void removeLocationListener(void Function(LocationSample) callback) {
    _locationListeners.remove(callback);
  }

  void onModeChange(void Function(TrackingMode) callback) {
    _modeChangeListeners.add(callback);
  }

  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> isLocationEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  void startTracking({TrackingMode mode = TrackingMode.highAccuracy}) {
    if (_isTracking) return;
    _isTracking = true;
    _setTrackingMode(mode);
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    _trackingMode = TrackingMode.idle;
    _recentSamples.clear();
    _lastSample = null;
    _previousSample = null;
    _sampleCount = 0;
  }

  void setTrackingMode(TrackingMode mode) {
    if (!_isTracking) return;
    _setTrackingMode(mode);
  }

  void _setTrackingMode(TrackingMode mode) {
    _positionSubscription?.cancel();
    _trackingMode = mode;

    final (LocationAccuracy accuracy, int distanceFilter) =
        _getTrackingParams(mode);

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).listen(_onPositionUpdate);

    for (final listener in _modeChangeListeners) {
      listener(mode);
    }
  }

  (LocationAccuracy, int) _getTrackingParams(TrackingMode mode) {
    switch (mode) {
      case TrackingMode.highAccuracy:
        return (LocationAccuracy.bestForNavigation, 3);
      case TrackingMode.mediumPower:
        return (LocationAccuracy.high, 10);
      case TrackingMode.lowPower:
        return (LocationAccuracy.medium, 25);
      case TrackingMode.idle:
        return (LocationAccuracy.low, 50);
    }
  }

  void adaptTrackingMode() {
    if (!_isTracking) return;
    final speed = currentSpeed;

    if (speed > 3.33) {
      if (_trackingMode != TrackingMode.highAccuracy) {
        _setTrackingMode(TrackingMode.highAccuracy);
      }
    } else if (speed > 1.67) {
      if (_trackingMode != TrackingMode.mediumPower) {
        _setTrackingMode(TrackingMode.mediumPower);
      }
    } else if (_trackingMode != TrackingMode.lowPower) {
      _setTrackingMode(TrackingMode.lowPower);
    }
  }

  void _onPositionUpdate(Position position) {
    _previousSample = _lastSample;
    _lastSample = LocationSample(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed,
      heading: position.heading,
      accuracy: position.accuracy,
    );

    _sampleCount++;
    _recentSamples.add(_lastSample!);
    if (_recentSamples.length > 30) {
      _recentSamples = _recentSamples.sublist(_recentSamples.length - 30);
    }

    adaptTrackingMode();

    for (final listener in _locationListeners) {
      listener(_lastSample!);
    }
  }

  double calculateDistanceTo(double lat, double lng) {
    if (_lastSample == null) return double.infinity;
    return haversineDistance(
      _lastSample!.latitude, _lastSample!.longitude,
      lat, lng,
    );
  }

  double calculateBearingTo(double lat, double lng) {
    if (_lastSample == null) return 0;
    return bearing(
      _lastSample!.latitude, _lastSample!.longitude,
      lat, lng,
    );
  }
}
