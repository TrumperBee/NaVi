import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:navi_app/services/location/live_location_service.dart';
import 'package:navi_app/features/journey/engines/stage_geofence_engine.dart';
import 'package:navi_app/features/journey/engines/boarding_detection_engine.dart';
import 'package:navi_app/features/journey/engines/route_matcher_engine.dart';
import 'package:navi_app/features/journey/engines/stop_progress_engine.dart';
import 'package:navi_app/features/journey/engines/alight_detection_engine.dart';
import 'package:navi_app/features/journey/engines/route_deviation_engine.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';
import 'package:navi_app/data/databases/route_database.dart';

class JourneyAutoDetector extends ChangeNotifier {
  final LiveLocationService _location = LiveLocationService();
  final StageGeofenceEngine _geofence = StageGeofenceEngine();
  final BoardingDetectionEngine _boarding = BoardingDetectionEngine();
  final RouteMatcherEngine _routeMatcher = RouteMatcherEngine();
  final StopProgressEngine _stopProgress = StopProgressEngine();
  final AlightDetectionEngine _alight = AlightDetectionEngine();
  final RouteDeviationEngine _deviation = RouteDeviationEngine();
  final RouteDatabase _routeDb = RouteDatabase();

  bool _isActive = false;
  bool _autoMode = true;

  JourneyPhase _detectedPhase = JourneyPhase.beforeTravel;
  bool _approachingSent = false;
  bool _alightSent = false;
  DeviationResult? _lastDeviation;

  bool get isActive => _isActive;
  bool get autoMode => _autoMode;
  JourneyPhase get detectedPhase => _detectedPhase;
  DeviationResult? get lastDeviation => _lastDeviation;

  // Callbacks for journey provider
  void Function()? onBoardingDetected;
  void Function(String stageName)? onStopReached;
  void Function()? onApproachingDestination;
  void Function()? onAlighted;
  void Function(DeviationResult)? onDeviation;

  double get currentSpeed => _location.currentSpeed;
  double get averageSpeed => _location.averageSpeed;
  MovementState get movementState => _boarding.currentState;
  double get routeConfidence => _routeMatcher.currentMatch?.confidence ?? 0;
  String? get currentStage => _stopProgress.currentStageName;
  String? get nextStage => _stopProgress.nextStageName;
  int get completedStops => _stopProgress.completedStops;
  int get totalStops => _stopProgress.totalStops;
  int get remainingStops => _stopProgress.remainingStops;
  List<GeofenceResult> get geofenceEvents => _geofence.recentEvents;
  double get boardingConfidence => _boarding.confidence;

  void toggleAutoMode() {
    _autoMode = !_autoMode;
    notifyListeners();
  }

  Future<void> startDetection({
    required double destinationLat,
    required double destinationLng,
    required double startLat,
    required double startLng,
    required List<String> routeStopNames,
  }) async {
    if (_isActive) return;
    _isActive = true;
    _approachingSent = false;
    _alightSent = false;
    _detectedPhase = JourneyPhase.walkingToStage;

    await _stopProgress.setRouteStops(routeStopNames);
    _alight.setDestination(destinationLat, destinationLng);
    _deviation.setJourneyBounds(startLat, startLng, destinationLat, destinationLng);

    _location.startTracking();
    _location.onLocation(_processSample);
  }

  void _processSample(LocationSample sample) {
    final lat = sample.latitude;
    final lng = sample.longitude;
    final speed = sample.speed;

    unawaited(_geofence.checkGeofences(lat, lng));

    final boardingResult = _boarding.analyze(speed);
    _routeMatcher.recordPoint(lat, lng);
    _deviation.recordUserPoint(lat, lng);

    if (_autoMode) {
      _detectPhaseTransitions(boardingResult, lat, lng, speed);
    }
  }

  void _detectPhaseTransitions(BoardingDetectionResult boardingResult, double lat, double lng, double speed) {
    switch (_detectedPhase) {
      case JourneyPhase.walkingToStage:
        if (boardingResult.didBoard) {
          _detectedPhase = JourneyPhase.waitingForMatatu;
    notifyListeners();
        }
        break;

      case JourneyPhase.waitingForMatatu:
        if (boardingResult.currentState == MovementState.inVehicle &&
            boardingResult.confidence > 0.6) {
          _detectedPhase = JourneyPhase.riding;
          onBoardingDetected?.call();
          notifyListeners();
        }
        break;

      case JourneyPhase.riding:
        final stopResult = _stopProgress.checkProgress(lat, lng);
        if (stopResult.stageChanged && stopResult.currentStageName != null) {
          onStopReached?.call(stopResult.currentStageName!);
        }

        final alightResult = _alight.analyze(lat, lng, speed);
        if (alightResult.isApproaching && !_approachingSent) {
          _detectedPhase = JourneyPhase.approachingDestination;
          _approachingSent = true;
          onApproachingDestination?.call();
          notifyListeners();
        }
        if (alightResult.hasAlighted && !_alightSent) {
          _detectedPhase = JourneyPhase.alighting;
          _alightSent = true;
          onAlighted?.call();
          notifyListeners();
        }
        break;

      case JourneyPhase.approachingDestination:
        final alightResult = _alight.analyze(lat, lng, speed);
        if (alightResult.hasAlighted && !_alightSent) {
          _detectedPhase = JourneyPhase.alighting;
          _alightSent = true;
          onAlighted?.call();
          notifyListeners();
        }
        break;

      default:
        break;
    }

    final deviationResult = _deviation.analyze(lat, lng);
    if (deviationResult.type != DeviationType.none && _lastDeviation?.type != deviationResult.type) {
      _lastDeviation = deviationResult;
      onDeviation?.call(deviationResult);
      notifyListeners();
    }
  }

  Future<void> matchRoute(String routeNumber) async {
    final routes = await _routeDb.searchRoutes(routeNumber);
    if (routes.isNotEmpty) {
      await _routeMatcher.matchToRoutes(routes);
    }
  }

  void stopDetection() {
    _location.removeLocationListener(_processSample);
    _location.stopTracking();
    _geofence.clearState();
    _boarding.reset();
    _routeMatcher.reset();
    _stopProgress.reset();
    _alight.reset();
    _deviation.reset();

    _isActive = false;
    _autoMode = true;
    _detectedPhase = JourneyPhase.beforeTravel;
    _approachingSent = false;
    _alightSent = false;
    _lastDeviation = null;

    notifyListeners();
  }
}
