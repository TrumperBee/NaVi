import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Position;

import '../models/transport_models.dart';
import '../services/firestore_service.dart';
import '../data/seed_data.dart';
import '../providers/navigation_provider.dart';
import '../providers/journey_provider.dart';
import '../services/settings_service.dart';
import '../services/mapbox_config.dart';
import '../features/map/mapbox_map_manager.dart';
import '../features/map/mode_toggle.dart';
import '../features/map/location_status.dart';
import '../features/map/instruction_card.dart';
import '../features/map/path_options_panel.dart';
import '../features/map/navigation_controls.dart';
import '../features/map/mapbox_layers.dart';
import '../features/map/map_journey_overlay.dart';
import '../features/map/live_map_layer.dart';
import '../features/journey/screens/journey_screen.dart';
import '../features/journey/widgets/favorites_bar.dart';
import '../features/journey/models/journey_models.dart';
import '../widgets/search_overlay.dart';
import '../widgets/navigation_overlay.dart';
import '../widgets/saved_destination_dialog.dart';

class MainMapScreen extends StatefulWidget {
  const MainMapScreen({super.key});

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> {
  final MapboxMapManager _mapManager = MapboxMapManager();
  final FirestoreService _firestoreService = FirestoreService();
  MapboxMap? _mapboxMap;

  StreamSubscription<List<StageModel>>? _stagesSubscription;
  StreamSubscription<List<PlaceModel>>? _placesSubscription;

  List<PlaceModel> _places = [];
  List<StageModel> _allStages = [];
  List<SavedDestination> _savedDestinations = [];
  double _currentZoom = _initialZoom;

  static const double _initialZoom = 15.0;
  static const double _navigationZoom = 17.0;
  static const LatLng _nairobiCenter = LatLng(-1.2833, 36.8167);

  @override
  void initState() {
    super.initState();
    debugPrint('[MAP_DEBUG] MainMapScreen initState called');
    _initNavigation();
    _loadData();
    _loadSavedDestinations();
    MapboxOptions.setAccessToken(MapboxConfig.accessToken);
    Future.delayed(const Duration(seconds: 1), _logDiagnostics);
  }

  void _logDiagnostics() {
    debugPrint('[MAP_DEBUG] ---- MAP DIAGNOSTICS ----');
    debugPrint('[MAP_DEBUG] ---- END DIAGNOSTICS ----');
  }

  void _loadSavedDestinations() {
    final settings = context.read<SettingsService>();
    final items = <SavedDestination>[];
    final home = settings.savedPlace(SavedPlaceKind.home);
    if (home != null && !home.isEmpty) {
      items.add(SavedDestination(
        id: 'home', label: home.label, latitude: home.lat, longitude: home.lng,
        type: SavedDestinationType.home,
      ));
    }
    final work = settings.savedPlace(SavedPlaceKind.work);
    if (work != null && !work.isEmpty) {
      items.add(SavedDestination(
        id: 'work', label: work.label, latitude: work.lat, longitude: work.lng,
        type: SavedDestinationType.work,
      ));
    }
    final campus = settings.savedPlace(SavedPlaceKind.campus);
    if (campus != null && !campus.isEmpty) {
      items.add(SavedDestination(
        id: 'campus', label: campus.label, latitude: campus.lat, longitude: campus.lng,
        type: SavedDestinationType.campus,
      ));
    }
    setState(() => _savedDestinations = items);
  }

  void _initNavigation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavigationProvider>().initializeLocation();
    });
  }

  @override
  void dispose() {
    _stagesSubscription?.cancel();
    _placesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    _stagesSubscription = _firestoreService.getStages().listen(
      (stages) {
        if (mounted) setState(() => _allStages = stages);
        context.read<NavigationProvider>().setStages(stages);
      },
      onError: (error) {
        print('Firestore stages error: $error, using SeedData');
        final fallback = SeedData.getStages();
        if (mounted) setState(() => _allStages = fallback);
        context.read<NavigationProvider>().setStages(fallback);
      },
    );

    _placesSubscription = _firestoreService.getPlaces().listen(
      (places) {
        if (mounted) setState(() => _places = places);
      },
      onError: (error) {
        print('Firestore places error: $error, using empty list');
      },
    );
  }

  void _toggleNavigationMode() {
    context.read<NavigationProvider>().toggleNavigationMode();
  }

  void _onAddFavorite(SavedDestinationType type) {
    showDialog(
      context: context,
      builder: (ctx) => SavedDestinationDialog(type: type),
    ).then((_) => _loadSavedDestinations());
  }

  void _startJourney(NavigationProvider nav, JourneyProvider journey) {
    if (nav.selectedPath == null || nav.endPoint == null) return;

    final path = nav.selectedPath!;
    final stopNames = path.path
        .where((n) => n.type == 'stage')
        .map((n) => n.name)
        .toList();

    final primaryRoute = path.routeNumbers.isNotEmpty
        ? path.routeNumbers.first
        : 'N/A';

    journey.startJourney(
      destinationName: nav.endName ?? 'Destination',
      destinationPoint: nav.endPoint!,
      fromStageName: path.path.isNotEmpty ? path.path.first.name : nav.currentStreet,
      fromStageId: path.path.isNotEmpty ? path.path.first.id : '',
      fromStageLocation: path.path.isNotEmpty ? path.path.first.location : nav.endPoint!,
      toStageName: path.path.isNotEmpty ? path.path.last.name : nav.endName ?? '',
      toStageId: path.path.isNotEmpty ? path.path.last.id : '',
      toStageLocation: path.path.isNotEmpty ? path.path.last.location : nav.endPoint!,
      routeNumber: primaryRoute,
      routeName: primaryRoute,
      estimatedFare: path.totalFare,
      estimatedDuration: (path.totalTime / 60).round(),
      stopNames: stopNames,
    );
  }

  void _startNavigation(String destination, LatLng point) {
    if (point.latitude == 0 && point.longitude == 0) {
      context.read<NavigationProvider>().toggleSearch();
      return;
    }
    context.read<NavigationProvider>().startNavigation(destination, point);
    final nav = context.read<NavigationProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (nav.routePolyline.isNotEmpty) {
        _fitRouteOnMap(nav.routePolyline);
      }
    });
  }

  void _fitRouteOnMap(List<LatLng> polyline) {
    if (polyline.isEmpty) return;

    double minLat = polyline.map((p) => p.latitude).reduce(min);
    double maxLat = polyline.map((p) => p.latitude).reduce(max);
    double minLng = polyline.map((p) => p.longitude).reduce(min);
    double maxLng = polyline.map((p) => p.longitude).reduce(max);

    _mapManager.flyTo(
      LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
      zoom: 14.0,
    );
  }

  void _syncMapAnnotations(
    NavigationProvider nav,
    JourneyProvider journey,
    Position? currentPosition,
    LatLng? endPoint,
    List<LatLng> routePolyline,
    List<LatLng> traveledRoute,
    List<LatLng> remainingRoute,
    bool isTransportMode,
  ) {
    _mapManager.clearAll();
    if (routePolyline.isNotEmpty || traveledRoute.isNotEmpty || remainingRoute.isNotEmpty) {
      MapboxLayers.setRoutePolylines(
        _mapManager,
        remainingRoute.isNotEmpty ? remainingRoute : routePolyline,
        traveledPoints: traveledRoute,
        color: isTransportMode ? const Color(0xFF008751) : Colors.blue,
      );
    }
    if (endPoint != null) {
      MapboxLayers.addDestinationMarker(_mapManager, endPoint);
    }
    if (currentPosition != null) {
      MapboxLayers.addUserLocationCircle(
        _mapManager,
        LatLng(currentPosition.latitude, currentPosition.longitude),
      );
    }
    MapboxLayers.addStageMarkers(_mapManager, _allStages);
    MapboxLayers.addPlaceMarkers(_mapManager, _places);
    if (journey.isActive) {
      // The raw route polyline above is the single line source on this
      // screen; straight connector paths would double-draw over it, so they
      // are only added when no route polyline is available.
      final noRoute =
          routePolyline.isEmpty && remainingRoute.isEmpty;
      JourneyMapLayers.applyToMap(
        manager: _mapManager,
        journey: journey,
        userLocation: currentPosition != null
            ? LatLng(currentPosition.latitude, currentPosition.longitude)
            : null,
        destinationPoint: endPoint,
        drawPaths: noRoute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return Consumer2<NavigationProvider, JourneyProvider>(
      builder: (context, nav, journey, child) {
        final isTransportMode = nav.isTransportMode;
        final currentPosition = nav.currentPosition;
        final endPoint = nav.endPoint;
        final routePolyline = nav.routePolyline;
        final traveledRoute = nav.traveledRoute;
        final remainingRoute = nav.remainingRoute;
        final currentInstructions = nav.currentInstructions;
        final currentInstructionIndex = nav.currentInstructionIndex;
        final selectedPath = nav.selectedPath;
        final pathOptions = nav.pathOptions;
        final showSearch = nav.showSearch;
        final showJourneyScreen = journey.showJourneyScreen;

        if (nav.hasArrived && !showJourneyScreen) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showArrivalDialog(nav));
        }

        return Scaffold(
          body: Stack(
            children: [
              if (showJourneyScreen)
                const JourneyScreen()
              else
                Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.blue, width: 4),
                          left: BorderSide(color: Colors.blue, width: 4),
                          right: BorderSide(color: Colors.blue, width: 4),
                          bottom: BorderSide(color: Colors.blue, width: 4),
                        ),
                      ),
                      child: MapWidget(
                        key: ValueKey("mainMap_${settings.isDarkTheme}"),
                        styleUri: MapboxConfig.styleForTheme(settings.isDarkTheme),
                        cameraOptions: CameraOptions(
                          center: Point.fromJson({
                            'type': 'Point',
                            'coordinates': [_nairobiCenter.longitude, _nairobiCenter.latitude],
                          }),
                          zoom: _initialZoom,
                        ),
                        mapOptions: MapOptions(
                          pixelRatio: MediaQuery.of(context).devicePixelRatio,
                          constrainMode: ConstrainMode.NONE,
                        ),
                        onMapCreated: (map) {
                          _mapboxMap = map;
                          _mapManager.onMapCreated(map);
                          _mapManager.enableLocation();
                          map.setBounds(CameraBoundsOptions(
                            maxZoom: 19.0,
                            minZoom: 11.0,
                          ));
                          _syncMapAnnotations(
                            nav, journey, currentPosition, endPoint,
                            routePolyline, traveledRoute, remainingRoute,
                            isTransportMode,
                          );
                        },
                      ),
                    ),

                    if (nav.isNavigating &&
                        routePolyline.isNotEmpty &&
                        currentInstructions.isNotEmpty)
                      NavigationOverlay(
                        routePoints: routePolyline,
                        instructions: currentInstructions,
                        currentInstructionIndex: currentInstructionIndex,
                        isTransportMode: isTransportMode,
                      ),

                    if (journey.isAutoDetecting && journey.isActive && !showJourneyScreen)
                      LiveInfoOverlay(
                        detector: journey.autoDetector,
                        largeText: journey.largeText,
                      ),

                    ModeToggle(
                      isTransportMode: isTransportMode,
                      onToggle: _toggleNavigationMode,
                    ),

                    LocationStatus(
                      hasLocation: currentPosition != null,
                      streetName: nav.currentStreet,
                    ),

                    if (showSearch)
                      SearchOverlay(
                        isTransportMode: isTransportMode,
                        userPosition: currentPosition != null
                            ? LatLng(currentPosition.latitude,
                                currentPosition.longitude)
                            : null,
                        onSelectDestination: _startNavigation,
                        onClose: () => nav.setShowSearch(false),
                      ),

                    PathOptionsPanel(
                      pathOptions: pathOptions,
                      selectedPath: selectedPath,
                      onSelectPath: (option) {
                        nav.selectPathOption(option);
                        _fitRouteOnMap(nav.routePolyline);
                      },
                    ),

                    Positioned(
                      bottom: 100,
                      left: 16,
                      right: 16,
                      child: InstructionCard(
                        instructions: currentInstructions,
                        currentInstructionIndex: currentInstructionIndex,
                        selectedPath: selectedPath,
                        routePolyline: routePolyline,
                        traveledRoute: traveledRoute,
                        remainingRoute: remainingRoute,
                        navigationStartTime: nav.navigationStartTime,
                      ),
                    ),

                    if (selectedPath != null &&
                        nav.isNavigating &&
                        !nav.showSearch)
                      Positioned(
                        bottom: 60,
                        left: 16,
                        right: 16,
                        child: ElevatedButton.icon(
                          onPressed: () => _startJourney(nav, journey),
                          icon: const Icon(Icons.navigation, color: Colors.white),
                          label: Text(
                            'Start Journey - ${selectedPath.formattedTime} · ${selectedPath.formattedFare}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF008751),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),

                    if (!showSearch &&
                        !nav.isNavigating &&
                        currentPosition != null)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 92,
                        left: 0,
                        right: 0,
                        child: FavoritesBar(
                          destinations: _savedDestinations,
                          onTap: (dest) {
                            _startNavigation(dest.label, LatLng(dest.latitude, dest.longitude));
                          },
                          onEdit: (dest) => _onAddFavorite(dest.type),
                          onAddHome: _savedDestinations.any((d) => d.type == SavedDestinationType.home)
                              ? null
                              : () => _onAddFavorite(SavedDestinationType.home),
                          onAddWork: _savedDestinations.any((d) => d.type == SavedDestinationType.work)
                              ? null
                              : () => _onAddFavorite(SavedDestinationType.work),
                          onAddCampus: _savedDestinations.any((d) => d.type == SavedDestinationType.campus)
                              ? null
                              : () => _onAddFavorite(SavedDestinationType.campus),
                        ),
                      ),

                    NavigationControls(
                      isNavigating: nav.isNavigating,
                      hasLocation: currentPosition != null,
                      onStopNavigation: () => nav.clearNavigation(),
                      onCenterLocation: () {
                        if (currentPosition != null) {
                          _mapManager.flyTo(
                            LatLng(currentPosition.latitude, currentPosition.longitude),
                            zoom: _navigationZoom,
                          );
                        }
                      },
                      onZoomIn: () {
                        _currentZoom = (_currentZoom + 0.5).clamp(11.0, 19.0);
                        _mapboxMap?.setCamera(
                          CameraOptions(zoom: _currentZoom),
                        );
                      },
                      onZoomOut: () {
                        _currentZoom = (_currentZoom - 0.5).clamp(11.0, 19.0);
                        _mapboxMap?.setCamera(
                          CameraOptions(zoom: _currentZoom),
                        );
                      },
                    ),

                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      right: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            heroTag: 'search',
                            mini: false,
                            onPressed: () => nav.toggleSearch(),
                            backgroundColor: const Color(0xFF008751),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              showSearch ? Icons.close : Icons.search,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FloatingActionButton(
                            heroTag: 'community',
                            mini: false,
                            onPressed: () => Navigator.pushNamed(context, '/community'),
                            backgroundColor: const Color(0xFF008751),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.groups, color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  void _showArrivalDialog(NavigationProvider nav) {
    final destName = nav.destinationName ?? 'Destination';
    final elapsed = nav.navigationStartTime != null
        ? DateTime.now().difference(nav.navigationStartTime!)
        : Duration.zero;
    final mins = elapsed.inMinutes;
    final secs = elapsed.inSeconds % 60;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.flag, color: Colors.green[700], size: 28),
            const SizedBox(width: 8),
            const Text('Arrived!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 48, color: Colors.red[400]),
            const SizedBox(height: 12),
            Text(destName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Travel time: ${mins}m ${secs}s'),
            Text('Well done, you made it!'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              nav.markArrivalComplete();
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('Done'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              nav.markArrivalComplete();
              nav.toggleSearch();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Navigate Again'),
          ),
        ],
      ),
    );
  }
}
