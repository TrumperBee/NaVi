import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';
import 'package:navi_app/features/journey/services/matatu_assistant.dart';
import 'package:navi_app/features/journey/services/journey_notifications.dart';
import 'package:navi_app/features/journey/engines/journey_auto_detector.dart';
import 'package:navi_app/features/journey/engines/route_deviation_engine.dart';
import 'package:navi_app/services/database/local_storage_service.dart';

class JourneyProvider extends ChangeNotifier {
  final MatatuAssistant _assistant = MatatuAssistant();
  final JourneyNotificationService _notifications = JourneyNotificationService();
  final LocalStorageService _storage = LocalStorageService();
  final JourneyAutoDetector _autoDetector = JourneyAutoDetector();

  JourneyPhase _currentPhase = JourneyPhase.beforeTravel;
  JourneyPhase _previousPhase = JourneyPhase.beforeTravel;

  String _destinationName = '';
  LatLng? _destinationPoint;
  String _fromStageName = '';
  String _fromStageId = '';
  LatLng? _fromStageLocation;
  String _toStageName = '';
  String _toStageId = '';
  LatLng? _toStageLocation;
  String _routeNumber = '';
  String _routeName = '';
  double _estimatedFare = 0.0;
  int _estimatedDuration = 0;
  int _totalStops = 0;

  String _currentStageName = '';
  int _completedStops = 0;
  double _progressFraction = 0.0;
  DateTime _startTime = DateTime.now();
  DateTime? _estimatedArrival;

  List<TimelineItem> _timelineItems = [];
  String _lastAssistantMessage = '';

  bool _isPaused = false;
  bool _showJourneyScreen = false;
  bool _highContrast = false;
  bool _largeText = false;
  bool _voiceGuidance = false;
  bool _notificationsEnabled = true;
  bool _autoAdvance = true;

  DeviationResult? _lastDeviation;
  String? _deviationMessage;

  Timer? _progressTimer;
  Timer? _notificationTimer;

  JourneyPhase get currentPhase => _currentPhase;
  JourneyPhase get previousPhase => _previousPhase;
  String get destinationName => _destinationName;
  LatLng? get destinationPoint => _destinationPoint;
  String get fromStageName => _fromStageName;
  LatLng? get fromStageLocation => _fromStageLocation;
  String get toStageName => _toStageName;
  LatLng? get toStageLocation => _toStageLocation;
  String get routeNumber => _routeNumber;
  String get routeName => _routeName;
  double get estimatedFare => _estimatedFare;
  int get estimatedDuration => _estimatedDuration;
  int get totalStops => _totalStops;
  String get currentStageName => _currentStageName;
  int get completedStops => _completedStops;
  double get progressFraction => _progressFraction;
  DateTime get startTime => _startTime;
  DateTime? get estimatedArrival => _estimatedArrival;
  List<TimelineItem> get timelineItems => _timelineItems;
  String get lastAssistantMessage => _lastAssistantMessage;
  bool get isPaused => _isPaused;
  bool get showJourneyScreen => _showJourneyScreen;
  bool get highContrast => _highContrast;
  bool get largeText => _largeText;
  bool get voiceGuidance => _voiceGuidance;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isActive => _currentPhase != JourneyPhase.beforeTravel &&
      _currentPhase != JourneyPhase.journeyComplete;

  bool get isNavigating => _showJourneyScreen && isActive;
  bool get autoAdvance => _autoAdvance;
  DeviationResult? get lastDeviation => _lastDeviation;
  String? get deviationMessage => _deviationMessage;
  JourneyAutoDetector get autoDetector => _autoDetector;
  double get currentSpeed => _autoDetector.currentSpeed;
  double get routeConfidence => _autoDetector.routeConfidence;
  bool get isAutoDetecting => _autoDetector.isActive;

  Duration get elapsedTime => DateTime.now().difference(_startTime);
  Duration get remainingTime {
    if (_estimatedArrival == null) return Duration.zero;
    final remaining = _estimatedArrival!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int get remainingStops => _totalStops - _completedStops;

  Future<void> loadPreferences() async {
    _highContrast = _storage.getSetting('high_contrast');
    _largeText = _storage.getSetting('large_text');
    _voiceGuidance = _storage.getSetting('voice_guidance');
    _notificationsEnabled = _storage.getSetting('notifications_enabled', defaultValue: true);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    await _storage.setSetting('high_contrast', value);
    notifyListeners();
  }

  Future<void> setLargeText(bool value) async {
    _largeText = value;
    await _storage.setSetting('large_text', value);
    notifyListeners();
  }

  Future<void> setVoiceGuidance(bool value) async {
    _voiceGuidance = value;
    await _storage.setSetting('voice_guidance', value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await _storage.setSetting('notifications_enabled', value);
    notifyListeners();
  }

  void toggleAutoAdvance() {
    _autoAdvance = !_autoAdvance;
    if (!_autoAdvance) {
      _autoDetector.stopDetection();
    } else if (_currentPhase == JourneyPhase.walkingToStage ||
               _currentPhase == JourneyPhase.waitingForMatatu ||
               _currentPhase == JourneyPhase.riding ||
               _currentPhase == JourneyPhase.approachingDestination) {
      unawaited(_startAutoDetection());
    }
    notifyListeners();
  }

  Future<void> startJourney({
    required String destinationName,
    required LatLng destinationPoint,
    required String fromStageName,
    required String fromStageId,
    required LatLng fromStageLocation,
    required String toStageName,
    required String toStageId,
    required LatLng toStageLocation,
    required String routeNumber,
    required String routeName,
    required double estimatedFare,
    required int estimatedDuration,
    required List<String> stopNames,
  }) async {
    _currentPhase = JourneyPhase.walkingToStage;
    _previousPhase = JourneyPhase.beforeTravel;
    _destinationName = destinationName;
    _destinationPoint = destinationPoint;
    _fromStageName = fromStageName;
    _fromStageId = fromStageId;
    _fromStageLocation = fromStageLocation;
    _toStageName = toStageName;
    _toStageId = toStageId;
    _toStageLocation = toStageLocation;
    _routeNumber = routeNumber;
    _routeName = routeName;
    _estimatedFare = estimatedFare;
    _estimatedDuration = estimatedDuration;
    _totalStops = stopNames.length;
    _completedStops = 0;
    _progressFraction = 0.0;
    _startTime = DateTime.now();
    _estimatedArrival = DateTime.now().add(Duration(minutes: estimatedDuration));
    _currentStageName = fromStageName;
    _showJourneyScreen = true;
    _isPaused = false;

    _buildTimeline(stopNames);
    _updateAssistant();
    _startTimers();

    if (_autoAdvance && _destinationPoint != null) {
      await _startAutoDetection();
    }

    notifyListeners();
  }

  void _buildTimeline(List<String> stopNames) {
    _timelineItems = [
      TimelineItem(
        id: 'walk_to_stage',
        label: 'Walk to $_fromStageName',
        status: TimelineItemStatus.current,
        isWalking: true,
        iconName: 'directions_walk',
      ),
      TimelineItem(
        id: 'board',
        label: 'Board Route $_routeNumber',
        subtitle: 'From $_fromStageName',
        status: TimelineItemStatus.pending,
        routeNumber: _routeNumber,
        iconName: 'directions_bus',
      ),
    ];

    for (int i = 0; i < stopNames.length; i++) {
      final isAlightingStop = stopNames[i] == _toStageName;
      _timelineItems.add(TimelineItem(
        id: 'stop_$i',
        label: isAlightingStop ? 'Alight at ${stopNames[i]}' : 'Pass ${stopNames[i]}',
        subtitle: isAlightingStop ? null : 'Stop ${i + 1} of ${stopNames.length}',
        status: TimelineItemStatus.pending,
        iconName: isAlightingStop ? 'flag' : 'location_on',
      ));
    }

    _timelineItems.add(TimelineItem(
      id: 'walk_to_dest',
      label: 'Walk to $_destinationName',
      status: TimelineItemStatus.pending,
      isWalking: true,
      iconName: 'directions_walk',
    ));

    _timelineItems.add(TimelineItem(
      id: 'arrived',
      label: 'Arrived at $_destinationName',
      status: TimelineItemStatus.pending,
      iconName: 'check_circle',
    ));
  }

  void advancePhase(JourneyPhase nextPhase) {
    _previousPhase = _currentPhase;
    _currentPhase = nextPhase;
    _updateTimelineForPhase(nextPhase);
    _updateAssistant();
    _scheduleNotificationForPhase(nextPhase);
    notifyListeners();
  }

  void advanceStop(String stageName) {
    _completedStops++;
    _currentStageName = stageName;
    _progressFraction = _totalStops > 0
        ? _completedStops / _totalStops
        : 0.0;

    final stopTimelineIndex = _completedStops + 1;
    if (stopTimelineIndex < _timelineItems.length) {
      _timelineItems[stopTimelineIndex] = _timelineItems[stopTimelineIndex]
          .copyWith(status: TimelineItemStatus.current);
    }
    for (int i = 1; i < stopTimelineIndex; i++) {
      if (i < _timelineItems.length) {
        _timelineItems[i] = _timelineItems[i]
            .copyWith(status: TimelineItemStatus.completed);
      }
    }

    if (_completedStops >= _totalStops - 2 &&
        _currentPhase == JourneyPhase.riding) {
      advancePhase(JourneyPhase.approachingDestination);
    }

    _updateAssistant();
    notifyListeners();
  }

  void markArrivedAtStage() {
    advancePhase(JourneyPhase.alighting);
    final boardIndex = _timelineItems.indexWhere(
      (t) => t.id.startsWith('stop_') && t.id.endsWith('_${_totalStops - 1}'),
    );
    for (int i = 0; i < _timelineItems.length; i++) {
      if (i <= boardIndex) {
        _timelineItems[i] = _timelineItems[i]
            .copyWith(status: TimelineItemStatus.completed);
      } else {
        _timelineItems[i] = _timelineItems[i]
            .copyWith(status: TimelineItemStatus.current);
      }
    }
    _updateAssistant();
    notifyListeners();
  }

  void markWalkingToDestination() {
    advancePhase(JourneyPhase.finalWalking);
    notifyListeners();
  }

  void markJourneyComplete() {
    advancePhase(JourneyPhase.journeyComplete);
    _stopTimers();
    for (int i = 0; i < _timelineItems.length; i++) {
      _timelineItems[i] = _timelineItems[i]
          .copyWith(status: TimelineItemStatus.completed);
    }
    _updateAssistant();
    notifyListeners();
  }

  void _updateTimelineForPhase(JourneyPhase phase) {
    switch (phase) {
      case JourneyPhase.walkingToStage:
        _timelineItems[0] = _timelineItems[0]
            .copyWith(status: TimelineItemStatus.current);
        break;
      case JourneyPhase.waitingForMatatu:
        _timelineItems[0] = _timelineItems[0]
            .copyWith(status: TimelineItemStatus.completed);
        _timelineItems[1] = _timelineItems[1]
            .copyWith(status: TimelineItemStatus.current);
        break;
      case JourneyPhase.riding:
        _timelineItems[1] = _timelineItems[1]
            .copyWith(status: TimelineItemStatus.completed);
        if (2 < _timelineItems.length) {
          _timelineItems[2] = _timelineItems[2]
              .copyWith(status: TimelineItemStatus.current);
        }
        break;
      case JourneyPhase.approachingDestination:
        break;
      case JourneyPhase.alighting:
        break;
      case JourneyPhase.finalWalking:
        break;
      case JourneyPhase.journeyComplete:
        for (int i = 0; i < _timelineItems.length; i++) {
          _timelineItems[i] = _timelineItems[i]
              .copyWith(status: TimelineItemStatus.completed);
        }
        break;
      case JourneyPhase.beforeTravel:
        break;
    }
  }

  void _updateAssistant() {
    _lastAssistantMessage = _assistant.getMessageForPhase(
      _currentPhase,
      routeNumber: _routeNumber,
      fromStage: _fromStageName,
      toStage: _toStageName,
      destination: _destinationName,
      remainingStops: remainingStops,
      fare: _estimatedFare,
      elapsedMinutes: elapsedTime.inMinutes,
    );
  }

  void _scheduleNotificationForPhase(JourneyPhase phase) {
    if (!_notificationsEnabled) return;
    final notification = _assistant.getNotificationForPhase(phase);
    if (notification != null) {
      _notifications.showNotification(notification);
    }
  }

  RouteProgress getRouteProgress() {
    return RouteProgress(
      completedStops: _completedStops,
      totalStops: _totalStops,
      progressFraction: _progressFraction,
      elapsed: elapsedTime,
      estimatedRemaining: remainingTime,
      estimatedArrival: _estimatedArrival ?? DateTime.now(),
    );
  }

  String getPhaseLabel() {
    switch (_currentPhase) {
      case JourneyPhase.beforeTravel:
        return 'Plan Your Journey';
      case JourneyPhase.walkingToStage:
        return 'Walking to Stage';
      case JourneyPhase.waitingForMatatu:
        return 'Waiting for Matatu';
      case JourneyPhase.riding:
        return 'En Route';
      case JourneyPhase.approachingDestination:
        return 'Approaching Destination';
      case JourneyPhase.alighting:
        return 'Prepare to Alight';
      case JourneyPhase.finalWalking:
        return 'Walking to Destination';
      case JourneyPhase.journeyComplete:
        return 'Journey Complete';
    }
  }

  String getPhaseEmoji() {
    switch (_currentPhase) {
      case JourneyPhase.beforeTravel:
        return '📍';
      case JourneyPhase.walkingToStage:
        return '🚶';
      case JourneyPhase.waitingForMatatu:
        return '🔄';
      case JourneyPhase.riding:
        return '🚌';
      case JourneyPhase.approachingDestination:
        return '📍';
      case JourneyPhase.alighting:
        return '⬇️';
      case JourneyPhase.finalWalking:
        return '🚶';
      case JourneyPhase.journeyComplete:
        return '✅';
    }
  }

  Future<void> _startAutoDetection() async {
    if (_destinationPoint == null) return;

    _autoDetector.onBoardingDetected = _autoDetectBoarding;
    _autoDetector.onStageArrived = _autoDetectStageArrived;
    _autoDetector.onStopReached = _autoDetectStopReached;
    _autoDetector.onApproachingDestination = _autoDetectApproaching;
    _autoDetector.onAlighted = _autoDetectAlighted;
    _autoDetector.onDeviation = _autoDetectDeviation;

    final coords = resolveAutoDetectionCoordinates();
    await _autoDetector.startDetection(
      destinationLat: coords.destLat,
      destinationLng: coords.destLng,
      startLat: coords.startLat,
      startLng: coords.startLng,
      routeStopNames: _timelineItems
          .where((t) => t.id.startsWith('stop_'))
          .map((t) => t.label.replaceAll('Pass ', '').replaceAll('Alight at ', ''))
          .toList(),
      routeNumber: _routeNumber,
    );
  }

  @visibleForTesting
  ({double startLat, double startLng, double destLat, double destLng})
      resolveAutoDetectionCoordinates() {
    return (
      startLat: _fromStageLocation?.latitude ?? -1.2833,
      startLng: _fromStageLocation?.longitude ?? 36.8167,
      destLat: _toStageLocation?.latitude ?? _destinationPoint?.latitude ?? -1.2833,
      destLng: _toStageLocation?.longitude ?? _destinationPoint?.longitude ?? 36.8167,
    );
  }

  void _autoDetectStageArrived() {
    if (!_autoAdvance) return;
    advancePhase(JourneyPhase.waitingForMatatu);
    _lastAssistantMessage = 'At $_fromStageName. Board Route $_routeNumber.';
    notifyListeners();
  }

  void _autoDetectBoarding() {
    if (!_autoAdvance) return;
    advancePhase(JourneyPhase.riding);
    _lastAssistantMessage = 'Auto-detected: You are now riding Route $_routeNumber.';
    notifyListeners();
  }

  void _autoDetectStopReached(String stageName) {
    if (!_autoAdvance) return;
    _currentStageName = stageName;
    advanceStop(stageName);
    notifyListeners();
  }

  void _autoDetectApproaching() {
    if (!_autoAdvance) return;
    advancePhase(JourneyPhase.approachingDestination);
    _lastAssistantMessage = 'You are approaching $_toStageName. Prepare to alight.';
    notifyListeners();
  }

  void _autoDetectAlighted() {
    if (!_autoAdvance) return;
    advancePhase(JourneyPhase.alighting);
    _lastAssistantMessage = 'Auto-detected: You have alighted at $_toStageName.';
    notifyListeners();
  }

  void _autoDetectDeviation(DeviationResult deviation) {
    _lastDeviation = deviation;
    _deviationMessage = deviation.message;
    _lastAssistantMessage = deviation.message ?? 'Route deviation detected.';
    notifyListeners();
  }

  void togglePause() {
    _isPaused = !_isPaused;
    notifyListeners();
  }

  void toggleJourneyScreen() {
    _showJourneyScreen = !_showJourneyScreen;
    notifyListeners();
  }

  void closeJourneyScreen() {
    _showJourneyScreen = false;
    notifyListeners();
  }

  void resetJourney() {
    _currentPhase = JourneyPhase.beforeTravel;
    _previousPhase = JourneyPhase.beforeTravel;
    _destinationName = '';
    _destinationPoint = null;
    _fromStageName = '';
    _fromStageId = '';
    _fromStageLocation = null;
    _toStageName = '';
    _toStageId = '';
    _toStageLocation = null;
    _routeNumber = '';
    _routeName = '';
    _estimatedFare = 0.0;
    _estimatedDuration = 0;
    _totalStops = 0;
    _currentStageName = '';
    _completedStops = 0;
    _progressFraction = 0.0;
    _timelineItems = [];
    _lastAssistantMessage = '';
    _isPaused = false;
    _showJourneyScreen = false;
    _estimatedArrival = null;
    _lastDeviation = null;
    _deviationMessage = null;
    _autoDetector.stopDetection();
    _stopTimers();
    notifyListeners();
  }

  void _startTimers() {
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      notifyListeners();
    });
    _notificationTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_currentPhase == JourneyPhase.riding) {
        final msg = _assistant.getRidingUpdate(
          routeNumber: _routeNumber,
          remainingStops: remainingStops,
          progressFraction: _progressFraction,
        );
        _lastAssistantMessage = msg;
        notifyListeners();
      }
    });
  }

  void _stopTimers() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _notificationTimer?.cancel();
    _notificationTimer = null;
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}
