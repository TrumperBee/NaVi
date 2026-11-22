import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/models/search_result.dart';
import 'package:navi_app/services/location_service.dart';
import 'package:navi_app/services/navigation_service.dart';
import 'package:navi_app/services/pathfinding_service.dart';
import 'package:navi_app/services/tts_service.dart';
import 'package:navi_app/services/fare_calculator_service.dart';
import 'package:navi_app/services/route_builder_service.dart';
import 'package:navi_app/services/walking_directions_service.dart';
import 'package:navi_app/services/gps_jitter_filter.dart';
import 'package:navi_app/features/map/trip_marker_anchors.dart';
import 'package:navi_app/data/seed_data.dart';

class NavigationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final NavigationService _navigationService = NavigationService();
  final PathfindingService _pathfindingService = PathfindingService();
  final FareCalculatorService _fareCalculatorService = FareCalculatorService();
  final RouteBuilderService _routeBuilderService = RouteBuilderService();
  final TtsService _ttsService = TtsService();

  bool _isTransportMode = true;
  bool _isNavigating = false;
  bool _showSearch = false;
  bool _hasArrived = false;
  bool _graphReady = false;
  bool _isLoadingRoute = false;

  // Routing preferences (synced from SettingsService)
  bool _avoidBusyJunctions = false;
  bool _preferWalkingPaths = false;
  bool _highAccuracyMode = true;

  Position? _currentPosition;
  String _currentStreet = '';
  StreamSubscription<Position>? _positionStreamSubscription;

  /// Smooths live fixes before they reach journey progress or the map.
  final GpsJitterFilter _positionFilter = GpsJitterFilter();

  /// The confirmed trip's departure anchor. This is deliberately separate from
  /// [_startPoint], which remains the routing origin and keeps following GPS
  /// for fresh route calculations. Marker code must only read this anchor.
  final TripMarkerAnchors _tripAnchors = TripMarkerAnchors();

  LatLng? _startPoint;
  LatLng? _endPoint;
  String? _endName;
  List<PathOption> _pathOptions = [];
  PathOption? _selectedPath;
  List<InstructionStep> _currentInstructions = [];
  int _currentInstructionIndex = 0;
  List<LatLng> _routePolyline = [];
  List<LatLng> _traveledRoute = [];
  List<LatLng> _remainingRoute = [];
  DateTime? _navigationStartTime;

  bool get isTransportMode => _isTransportMode;
  bool get isNavigating => _isNavigating;
  bool get showSearch => _showSearch;
  bool get hasArrived => _hasArrived;
  bool get graphReady => _graphReady;
  bool get isLoadingRoute => _isLoadingRoute;
  Position? get currentPosition => _currentPosition;
  String get currentStreet => _currentStreet;

  /// Fixed coordinate the confirmed journey was planned from. Never updated
  /// from the live location stream.
  LatLng? get plannedDeparture => _tripAnchors.departure;

  /// Stores the departure anchor once per confirmed journey. Later GPS fixes
  /// cannot change it; [clearNavigation] resets it for the next journey.
  bool confirmPlannedDeparture(LatLng point) {
    final changed = _tripAnchors.confirmDeparture(point);
    if (changed) notifyListeners();
    return changed;
  }

  void clearPlannedDeparture() {
    if (_tripAnchors.clear()) notifyListeners();
  }

  LatLng? get startPoint => _startPoint;
  LatLng? get endPoint => _endPoint;
  String? get endName => _endName;
  List<PathOption> get pathOptions => _pathOptions;
  PathOption? get selectedPath => _selectedPath;
  List<InstructionStep> get currentInstructions => _currentInstructions;
  int get currentInstructionIndex => _currentInstructionIndex;
  List<LatLng> get routePolyline => _routePolyline;
  List<LatLng> get traveledRoute => _traveledRoute;
  List<LatLng> get remainingRoute => _remainingRoute;
  DateTime? get navigationStartTime => _navigationStartTime;

  // Routing preferences
  bool get avoidBusyJunctions => _avoidBusyJunctions;
  bool get preferWalkingPaths => _preferWalkingPaths;
  bool get highAccuracyMode => _highAccuracyMode;

  void setRoutingPreferences({
    bool? avoidBusyJunctions,
    bool? preferWalkingPaths,
    bool? highAccuracyMode,
  }) {
    if (avoidBusyJunctions != null) _avoidBusyJunctions = avoidBusyJunctions;
    if (preferWalkingPaths != null) _preferWalkingPaths = preferWalkingPaths;
    if (highAccuracyMode != null) _highAccuracyMode = highAccuracyMode;
    if (highAccuracyMode != null) {
      _locationService.setHighAccuracy(_highAccuracyMode);
    }
  }

  /// Re-applies GPS accuracy and restarts the live tracking stream so the
  /// new accuracy takes effect immediately (geolocator streams are fixed at
  /// creation time).
  void reconfigurePositionStream({bool? highAccuracy}) {
    if (highAccuracy != null) {
      _highAccuracyMode = highAccuracy;
      _locationService.setHighAccuracy(highAccuracy);
    }
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    if (_startPoint != null && _isNavigating) {
      _startLiveTracking();
    }
    notifyListeners();
  }

  // Arrival stats for completion dialog
  String? get destinationName => _endName;

  void setStages(List<StageModel> stages) {
    _pathfindingService.initializeGraph(stages, []);
    _graphReady = true;
  }

  Future<void> initializeLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      final street = await _locationService.getStreetName(
        position.latitude,
        position.longitude,
      );
      _currentPosition = position;
      _currentStreet = street;
      final initial = LatLng(position.latitude, position.longitude);
      _startPoint = initial;
      _positionFilter.seed(initial);
      _startLiveTracking();
      notifyListeners();
    } catch (e) {
      print('Location error: $e');
      _currentStreet = 'Nairobi CBD';
      const fallback = LatLng(-1.2833, 36.8167);
      _startPoint = fallback;
      _positionFilter.seed(fallback);
      notifyListeners();
    }
  }

  void _startLiveTracking() {
    _positionStreamSubscription = _locationService
        .startLiveTracking(
          distanceFilter: GpsJitterFilter.defaultMinimumDistanceMeters,
        )
        .listen((position) async {
      // Sub-5m oscillation is jitter, not movement. Ignore it before any
      // progress, routing-origin or UI work happens.
      if (!_positionFilter
          .shouldAccept(LatLng(position.latitude, position.longitude))) {
        return;
      }
      final street = await _locationService.getStreetName(
        position.latitude,
        position.longitude,
      );
      _currentPosition = position;
      _currentStreet = street;
      _startPoint = LatLng(position.latitude, position.longitude);
      if (_isNavigating) {
        _checkProgress(position);
      }
      notifyListeners();
    });
  }

  void _checkProgress(Position position) {
    final userPoint = LatLng(position.latitude, position.longitude);
    if (_routePolyline.isEmpty) return;

    _updateRouteProgress(userPoint);

    if (_endPoint != null) {
      final distToDest = _navigationService.calculateDistance(userPoint, _endPoint!);
      if (distToDest < 50 && !_hasArrived) {
        _hasArrived = true;
        notifyListeners();
        return;
      }
    }

    if (_currentInstructions.isEmpty) return;
    final currentTarget = _routePolyline.length > _currentInstructionIndex + 1
        ? _routePolyline[_currentInstructionIndex + 1]
        : _routePolyline.last;
    final distance = _navigationService.calculateDistance(userPoint, currentTarget);
    if (distance < 20 && _currentInstructionIndex < _currentInstructions.length - 1) {
      _currentInstructionIndex++;
      final instruction = _currentInstructions.isNotEmpty &&
          _currentInstructionIndex < _currentInstructions.length
          ? _currentInstructions[_currentInstructionIndex].instruction
          : '';
      if (instruction.isNotEmpty) {
        _ttsService.speak(instruction);
      }
      notifyListeners();
    }
  }

  void _updateRouteProgress(LatLng userPoint) {
    if (_routePolyline.isEmpty) {
      _traveledRoute = [];
      _remainingRoute = [];
      return;
    }

    final thresholdMeters = 30.0;
    int furthestPassed = 0;

    for (int i = _traveledRoute.length; i < _routePolyline.length; i++) {
      final dist = _navigationService.calculateDistance(userPoint, _routePolyline[i]);
      if (dist < thresholdMeters) {
        furthestPassed = i + 1;
      }
    }

    if (furthestPassed > _traveledRoute.length) {
      _traveledRoute = _routePolyline.sublist(0, furthestPassed);
      _remainingRoute = furthestPassed < _routePolyline.length
          ? _routePolyline.sublist(furthestPassed)
          : [];
    } else if (_traveledRoute.isEmpty) {
      _traveledRoute = [];
      _remainingRoute = List.from(_routePolyline);
    }
  }

  void toggleNavigationMode() {
    _isTransportMode = true;
    clearNavigation();
    notifyListeners();
  }

  void startNavigation(String destination, LatLng point) {
    // A new destination means a new journey: drop the previous fixed anchor so
    // the next confirmed route can store its own planned departure.
    clearPlannedDeparture();
    _endPoint = point;
    _endName = destination;
    _isNavigating = true;
    _showSearch = false;
    _hasArrived = false;
    _navigationStartTime = DateTime.now();
    _traveledRoute = [];
    _remainingRoute = [];
    _routePolyline = [];
    _currentInstructions = [];
    _selectedPath = null;
    _isTransportMode = true;
    _isLoadingRoute = true;
    notifyListeners();
    if (!_graphReady) {
      _pathfindingService.initializeGraph(SeedData.getStages(), []);
      _graphReady = true;
    }
    _calculateTransportRoute();
  }

  Future<void> _calculateTransportRoute() async {
    debugPrint('[NAV] _calculateTransportRoute: start=$_startPoint end=$_endPoint');
    if (_startPoint == null || _endPoint == null) {
      debugPrint('[NAV] _calculateTransportRoute: SKIP - start or end is null');
      _isLoadingRoute = false;
      notifyListeners();
      return;
    }
    try {
      var options = _pathfindingService.findBestRoutes(_startPoint!, _endPoint!);
      debugPrint('[NAV] _calculateTransportRoute: initial options=${options.length}');
      if (options.isEmpty) {
        debugPrint('[NAV] _calculateTransportRoute: retrying with fresh graph init');
        _pathfindingService.initializeGraph(SeedData.getStages(), []);
        options = _pathfindingService.findBestRoutes(_startPoint!, _endPoint!);
        debugPrint('[NAV] _calculateTransportRoute: after retry options=${options.length}');
      }
      _pathOptions = options;
      if (options.isNotEmpty) {
        _selectedPath = options.first;
        debugPrint('[NAV] selected path: ${options.first.description} polyline edges=${options.first.edges.length} route=${options.first.routeNumbers}');
        _buildRoutePolyline(options.first);
        debugPrint('[NAV] routePolyline length=${_routePolyline.length}');
        await _loadTransportInstructions(options.first);
        debugPrint('[NAV] instructions count=${_currentInstructions.length}');
        _remainingRoute = List.from(_routePolyline);
      } else {
        debugPrint('[NAV] NO ROUTE FOUND - falling back to walking directions');
        final walk = await RouteBuilderService.walkingDirections
            .route(_startPoint!, _endPoint!);
        _routePolyline = List<LatLng>.of(walk.points);
        _remainingRoute = List.from(_routePolyline);
        _loadWalkingInstructions(walk);
        _selectedPath = _buildWalkingPathOption(walk);
      }
    } catch (e, s) {
      debugPrint('[NAV] Route calculation error: $e\n$s');
    }
    _isLoadingRoute = false;
    notifyListeners();
  }

  void _buildRoutePolyline(PathOption option) {
    _routePolyline = [];
    if (_startPoint != null) _routePolyline.add(_startPoint!);
    for (var node in option.path) {
      _routePolyline.add(LatLng(node.lat, node.lng));
    }
    if (_endPoint != null) _routePolyline.add(_endPoint!);
  }

  // OSRM road-following pass removed: walking legs are resolved against the
  // road network by WalkingDirectionsService inside RouteBuilderService, and
  // the ride legs already carry corridor geometry. Re-routing the whole
  // stitched polyline through a car profile produced the out-and-back spikes.

  Future<void> _loadTransportInstructions(PathOption option) async {
    final instructions = await _navigationService.getTransportInstructions(
      option.path,
      option.edges,
    );
    _currentInstructions = instructions;
    _currentInstructionIndex = 0;
    notifyListeners();
  }

  void _loadWalkingInstructions(WalkingRoute walk) {
    final start = walk.points.first;
    final end = walk.points.last;
    _currentInstructions = [
      InstructionStep(
        instruction:
            'Walk to ${_endName ?? 'your destination'} ${_navigationService.formatDistance(walk.distanceMeters)}',
        distance: walk.distanceMeters,
        duration: walk.durationSeconds.round(),
        type: 'walk',
        icon: '🚶',
        startNode: Node(
            id: 'start',
            name: _currentStreet,
            lat: start.latitude,
            lng: start.longitude,
            type: 'temporary'),
        endNode: Node(
            id: 'dest_end',
            name: _endName ?? 'Destination',
            lat: end.latitude,
            lng: end.longitude,
            type: 'temporary'),
      ),
    ];
    _currentInstructionIndex = 0;
    notifyListeners();
  }

  PathOption _buildWalkingPathOption(WalkingRoute walk) {
    final distance = walk.distanceMeters;
    final duration = walk.durationSeconds;
    final startNode = Node(id: 'start', name: _currentStreet, lat: _startPoint!.latitude, lng: _startPoint!.longitude, type: 'temporary');
    final endNode = Node(id: 'dest', name: _endName ?? 'Destination', lat: _endPoint!.latitude, lng: _endPoint!.longitude, type: 'temporary');
    final edge = Edge(
      id: 'walk_direct',
      from: startNode,
      to: endNode,
      distance: distance,
      routeNumbers: ['walk'],
      averageTime: duration.round(),
      baseFare: 0,
      trafficLevel: 'low',
      lastUpdated: DateTime.now(),
    );
    return PathOption(
      path: [startNode, endNode],
      edges: [edge],
      totalDistance: distance,
      totalTime: duration.round(),
      totalFare: 0,
      transferCount: 0,
      routeNumbers: ['walk'],
      description: 'Walk to ${_endName ?? 'destination'}',
    );
  }

  void selectPathOption(PathOption option) async {
    _selectedPath = option;
    _buildRoutePolyline(option);
    await _loadTransportInstructions(option);
    
    // Recalculate fare using the new fare calculator
    if (_startPoint != null && _endPoint != null) {
      try {
        final journey = await RouteBuilderService.build(
          origin: _startPoint!,
          destination: SearchResult(
            query: _endName ?? 'Destination',
            lat: _endPoint!.latitude,
            lng: _endPoint!.longitude,
            resolvedLabel: _endName ?? 'Destination',
            matchedCorridorName: _selectedPath?.edges.isNotEmpty == true 
                ? _selectedPath!.edges.first.routeNumbers.first 
                : null,
            nearestStageName: _endName ?? 'Destination',
            nearestStageLat: _endPoint!.latitude,
            nearestStageLng: _endPoint!.longitude,
            routeNumbers: _selectedPath?.routeNumbers ?? [],
            distanceToStageMeters: 0.0,
            source: SearchResultSource.exactStage,
          ),
        );
        final totalFare = FareCalculatorService.calculateJourneyTotal(journey.segments);
        // Create a new PathOption with updated fare
        _selectedPath = PathOption(
          path: option.path,
          edges: option.edges,
          totalDistance: option.totalDistance,
          totalTime: option.totalTime,
          totalFare: totalFare.toDouble(),
          transferCount: option.transferCount,
          routeNumbers: option.routeNumbers,
          description: option.description,
        );
      } catch (e) {
        debugPrint('[NAV] Fare calculation failed: $e');
        // Keep original fare if calculation fails
      }
    }
    
    notifyListeners();
  }

  void clearNavigation() {
    clearPlannedDeparture();
    _isNavigating = false;
    _hasArrived = false;
    _endPoint = null;
    _endName = null;
    _pathOptions = [];
    _selectedPath = null;
    _routePolyline = [];
    _traveledRoute = [];
    _remainingRoute = [];
    _currentInstructions = [];
    _currentInstructionIndex = 0;
    _navigationStartTime = null;
    notifyListeners();
  }

  void toggleSearch() {
    _showSearch = !_showSearch;
    notifyListeners();
  }

  void setShowSearch(bool show) {
    _showSearch = show;
    notifyListeners();
  }

  void markArrivalComplete() {
    _hasArrived = false;
    clearNavigation();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}
