import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/journey_record.dart';
import 'package:navi_app/models/proximity_threshold.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/models/search_result.dart';
import 'package:navi_app/services/location_service.dart';
import 'package:navi_app/services/proximity_alert_service.dart';
import 'package:navi_app/services/route_builder_service.dart';
import 'package:navi_app/services/polyline_renderer.dart';
import 'package:navi_app/services/tts_service.dart';
import 'package:navi_app/features/map/mapbox_map_manager.dart';

class ActiveJourneyViewModel extends ChangeNotifier {
  final MapboxMapManager _mapManager;
  final PolylineRendererService _polylineRenderer;
  final ProximityAlertService _proximityService;
  
  ActiveJourney? _activeJourney;
  String _currentInstruction = '';
  StreamSubscription<Position>? _positionSubscription;
  bool _isJourneyActive = false;
  Timer? _instructionUpdateTimer;
  int _lastSegmentIndex = -1;

  String? _originLabel;
  String? _destinationLabel;
  bool _completionRecorded = false;

  /// Invoked exactly once when a live journey completes (the traveller
  /// reaches the destination) so the owner can persist a [JourneyRecord].
  /// Never fired for cancelled trips.
  ValueChanged<JourneyRecord>? onJourneyCompleted;

  ActiveJourneyViewModel(this._mapManager)
      : _polylineRenderer = PolylineRendererService(_mapManager),
        _proximityService = ProximityAlertService();

  ActiveJourney? get activeJourney => _activeJourney;
  String get currentInstruction => _currentInstruction;
  bool get isJourneyActive => _isJourneyActive;
  RouteSegment? get currentSegment => _activeJourney?.currentSegment;
  List<RouteSegment> get segments => _activeJourney?.segments ?? [];
  int get currentSegmentIndex => _activeJourney?.currentSegmentIndex ?? 0;
  double get progressAlongCurrentSegment => _activeJourney?.progressAlongCurrentSegment ?? 0.0;
  bool get isComplete => _activeJourney?.isComplete ?? false;
  Stream<ProximityAlertEvent> get proximityEvents => _proximityService.events;

  /// Start a new journey from origin to destination
  Future<void> startJourney({
    required LatLng origin,
    required SearchResult destination,
    bool preferWalkingPaths = false,
    bool avoidBusyJunctions = false,
    String? originLabel,
    String? destinationLabel,
  }) async {
    // Build the journey (honouring the navigation preferences)
    final journey = await RouteBuilderService.build(
      origin: origin,
      destination: destination,
      preferWalkingPaths: preferWalkingPaths,
      avoidBusyJunctions: avoidBusyJunctions,
    );

    await startJourneyWith(journey,
        originLabel: originLabel, destinationLabel: destinationLabel);
  }

  /// Adopt an already-built journey (e.g. the pre-trip confirmed route) so
  /// the route is computed exactly once and shared by preview + live nav.
  Future<void> startJourneyWith(
    ActiveJourney journey, {
    String? originLabel,
    String? destinationLabel,
  }) async {
    _activeJourney = journey;
    _isJourneyActive = true;
    _lastSegmentIndex = journey.currentSegmentIndex;
    _originLabel = originLabel;
    _destinationLabel = destinationLabel;
    _completionRecorded = false;
    _currentInstruction = _generateInstruction(journey.currentSegment);

    // Initialize proximity alerts for the first segment
    _updateProximityTarget();

    // Render the full journey on map
    await _polylineRenderer.renderJourney(journey);

    // Start GPS tracking (reuse existing stream pattern)
    _startPositionTracking();

    // Start instruction update timer
    _startInstructionTimer();

    notifyListeners();
  }

  /// Re-render the current journey route on the map. Called when the map
  /// widget is (re)created during live navigation so the polyline survives an
  /// instance swap.
  Future<void> reRenderJourney() async {
    final journey = _activeJourney;
    if (journey == null) return;
    await _polylineRenderer.renderJourney(journey);
  }

  /// Start listening to GPS position updates. Accuracy follows the current
  /// "High accuracy mode" setting via [LocationService], so the toggle has a
  /// real effect on the live stream (not just one-shot position reads).
  void _startPositionTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = LocationService()
        .startLiveTracking(distanceFilter: 5)
        .listen(_onPositionUpdate);
  }

  /// Restarts the live position stream (used when the high-accuracy setting
  /// changes mid-journey — the geolocator stream is fixed at creation time).
  void reconfigurePositionStream() {
    if (!_isJourneyActive) return;
    _startPositionTracking();
  }

  void _onPositionUpdate(Position position) {
    if (!_isJourneyActive || _activeJourney == null) return;

    final latLng = LatLng(position.latitude, position.longitude);
    _activeJourney!.updatePosition(latLng);
    
    // Update polyline rendering (progressive fading)
    _polylineRenderer.updateCurrentSegment(_activeJourney!);
    
    // Check proximity alerts
    _proximityService.checkProximity(latLng);
    
    // Check if segment changed
    _checkSegmentTransition();
    
    _currentInstruction = _generateInstruction(_activeJourney!.currentSegment);

    // Progress bar, timeline and remaining-time metrics move with EVERY
    // position update, not just when the instruction text changes — always
    // notify or the HUD appears frozen.
    notifyListeners();
    
    // Check if journey complete
    if (_activeJourney!.isComplete) {
      _completeJourney();
    }
  }

  void _checkSegmentTransition() {
    if (_activeJourney == null) return;
    final currentIndex = _activeJourney!.currentSegmentIndex;
    if (currentIndex != _lastSegmentIndex) {
      _lastSegmentIndex = currentIndex;
      _updateProximityTarget();
      _polylineRenderer.updateCurrentSegment(_activeJourney!);
      // Voice guidance: read the new maneuver once we actually step onto it.
      // TtsService self-gates on the voice-guidance setting.
      TtsService().speak(_generateInstruction(_activeJourney!.currentSegment));
    }
  }

  void _updateProximityTarget() {
    if (_activeJourney == null) return;
    final segment = _activeJourney!.currentSegment;
    if (segment == null) return;

    final isFinal = _activeJourney!.currentSegmentIndex == _activeJourney!.segments.length - 1 &&
        segment.mode == SegmentMode.walk;
    
    final target = ProximityTarget.fromStage(
      segment.label,
      segment.endPoint.latitude,
      segment.endPoint.longitude,
      isFinal: isFinal,
    );
    _proximityService.resetForNewTarget(target);
  }

  String _generateInstruction(RouteSegment? segment) {
    if (segment == null) return 'Journey complete!';
    return segment.label;
  }

  void _startInstructionTimer() {
    _instructionUpdateTimer?.cancel();
    _instructionUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_activeJourney != null && _activeJourney!.currentSegment != null) {
        _currentInstruction = _generateInstruction(_activeJourney!.currentSegment);
        notifyListeners();
      }
    });
  }

  void _completeJourney() {
    _isJourneyActive = false;
    _currentInstruction = 'Journey complete! Arrived at destination.';
    _positionSubscription?.cancel();
    _instructionUpdateTimer?.cancel();
    _polylineRenderer.clearJourney();
    _recordCompletionIfNeeded();
    notifyListeners();
  }

  /// Emits the completed-trip record exactly once, so profile stats and
  /// journey history are driven by real completions — not cancelled trips.
  void _recordCompletionIfNeeded() {
    if (_completionRecorded) return;
    final journey = _activeJourney;
    if (journey == null) return;
    _completionRecorded = true;
    onJourneyCompleted?.call(JourneyRecord.fromJourney(
      journey,
      originLabel: _originLabel ?? '',
      destinationLabel: _destinationLabel ?? '',
    ));
  }

  /// Cancel the current journey
  void cancelJourney() {
    _isJourneyActive = false;
    _positionSubscription?.cancel();
    _instructionUpdateTimer?.cancel();
    _polylineRenderer.clearJourney();
    _activeJourney = null;
    _currentInstruction = '';
    notifyListeners();
  }

  /// Pause/resume journey
  void pauseJourney() {
    _positionSubscription?.pause();
  }

  void resumeJourney() {
    _positionSubscription?.resume();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _instructionUpdateTimer?.cancel();
    _polylineRenderer.clearJourney();
    _proximityService.dispose();
    super.dispose();
  }
}