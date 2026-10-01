import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Position;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transport_models.dart';
import '../models/active_journey.dart';
import '../models/route_segment.dart' show SegmentMode;
import '../models/search_result.dart';
import '../viewmodels/active_journey_viewmodel.dart';
import '../services/firestore_service.dart';
import '../services/geocoding_service.dart';
import '../services/distance_calculator.dart';
import '../services/tts_service.dart';
import '../services/route_builder_service.dart';
import '../services/polyline_renderer.dart';
import '../data/seed_data.dart';
import '../services/settings_service.dart';
import '../providers/navigation_provider.dart';
import '../providers/journey_provider.dart';
import '../services/mapbox_config.dart';
import '../features/map/mapbox_map_manager.dart';
import '../features/map/mapbox_layers.dart';
import '../features/map/map_journey_overlay.dart';
import '../features/journey/models/journey_models.dart';
import '../design/navi_colors.dart';
import '../design/navi_typography.dart';
import '../widgets/hero_go_card.dart';
import '../widgets/homepage_entrance_animation.dart';
import '../widgets/nearby_stages_list.dart';
import '../widgets/quick_go_row.dart';
import '../widgets/search_overlay.dart';
import '../widgets/saved_destination_dialog.dart';
import '../widgets/arrival_alert_modal.dart';
import '../utils/distance_formatter.dart';
import '../models/proximity_threshold.dart';
import 'stage_details_sheet.dart';
import 'navigation_overlay.dart';
import 'profile_screen.dart';
import '../core/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapboxMapManager _mapManager = MapboxMapManager();
  final FirestoreService _firestoreService = FirestoreService();
  final TtsService _ttsService = TtsService();
  late final ActiveJourneyViewModel _activeJourneyVM;

  /// Renders the segmented confirmed-route polyline (dashed green walk,
  /// solid blue matatu) on the shared map manager.
  late final PolylineRendererService _polylineRenderer =
      PolylineRendererService(_mapManager);

  /// Whether the polyline renderer currently owns the on-map journey line.
  /// True from the moment a confirmed pre-trip preview exists. Once the
  /// journey panel opens and the ActiveJourneyViewModel takes over, its
  /// live renderer keeps drawing the same stitched line, so the legacy
  /// straight connector paths must not be re-drawn on top.
  bool get _polylineRendererOwnsActiveRoute =>
      _confirmedJourney != null || _activeJourneyVM.isJourneyActive;

  /// The single confirmed-route object for the current pre-trip overview.
  /// Built exactly once per (destination, route) selection and shared by the
  /// top summary card, the bottom metrics row, the polyline and the journey
  /// start — no independent recomputation anywhere.
  ActiveJourney? _confirmedJourney;

  /// Identity of the route the [_confirmedJourney] was built for, so it is
  /// rebuilt when the destination or selected route changes.
  String? _confirmedRouteKey;

  MapboxMap? _mapboxMap;

  StreamSubscription<List<StageModel>>? _stagesSubscription;
  StreamSubscription<List<PlaceModel>>? _placesSubscription;
  StreamSubscription<ProximityAlertEvent>? _proximitySubscription;

  List<PlaceModel> _places = [];
  List<StageModel> _allStages = [];
  List<SavedDestination> _savedDestinations = [];
  bool _showSearch = false;
  bool _showJourneyPanel = false;

  /// Re-entrancy guard so a retry cannot stack a second location request.
  bool _locationRequestRunning = false;

  /// Set when no GPS fix arrived within [_locationFixTimeout]; swaps the
  /// shimmer for the actionable "still finding your location" retry card.
  bool _locationTimedOut = false;

  /// True for a short beat after GPS resolves, so the loading card can
  /// visibly transition "Getting your location…" → "Finding nearby stages…"
  /// instead of flashing the live card in the same frame.
  bool _showStageLookup = false;

  Timer? _locationFixTimer;

  /// Brief staged-beat timer that holds the "Finding nearby stages…" phase
  /// long enough to be visible (location → stage transition) before the live
  /// hero card lands.
  Timer? _locationStageTimer;

  /// True when the user has denied (or never granted) location permission, so
  /// the map can surface an inline prompt instead of silently hiding the puck.
  bool _locationDenied = false;

  /// One-time "Swipe up for more stages" scroll hint; persisted so it is shown
  /// exactly once per install and dismissed on the first sheet drag.
  bool _sheetSwipeHintVisible = false;
  bool _sheetDragListenerAttached = false;
  ScrollController? _sheetScrollController;
  bool _overlayStyleSyncedForDark = false;
  static const String _sheetSwipeHintKey = 'navi.hints.sheetSwipeShown';

  double _currentZoom = _initialZoom;

  static const double _initialZoom = 15.0;
  static const double _navigationZoom = 17.0;
  static const double _topBarHeight = 52.0;
  static const double _quickGoGap = 12.0;
  static const double _quickGoHeight = QuickGoRow.rowHeight;

  /// Stages beyond this distance are not "nearby"; the hero goes empty state.
  static const double _nearbyRangeMeters = 5000.0;

  /// Ceiling on how long we shimmer while waiting for a GPS fix, so the
  /// homepage can never hang on an infinite loading state. After this fires
  /// the hero swaps to the retry card.
  static const Duration _locationFixTimeout = Duration(seconds: 8);

  /// How long the "Finding nearby stages…" beat stays on screen before the
  /// live hero card lands, so the GPS → stage transition reads deliberately.
  static const Duration _stageLookupTransition = Duration(milliseconds: 500);

  static const LatLng _nairobiCenter = LatLng(-1.2833, 36.8167);

  static const double _nairobiMinLat = -1.45;
  static const double _nairobiMaxLat = -1.15;
  static const double _nairobiMinLng = 36.65;
  static const double _nairobiMaxLng = 37.00;

  bool _isWithinNairobi(double lat, double lng) {
    return lat >= _nairobiMinLat &&
        lat <= _nairobiMaxLat &&
        lng >= _nairobiMinLng &&
        lng <= _nairobiMaxLng;
  }

  @override
  void initState() {
    super.initState();
    _activeJourneyVM = ActiveJourneyViewModel(_mapManager);
    _initNavigation();
    _loadData();
    _loadSavedDestinations();
    _loadSheetSwipeHintState();
    MapboxOptions.setAccessToken(MapboxConfig.accessToken);
    _ttsService.init();
    _wireProximityAlerts();
    _wireJourneyCompletion();
    // STATUS-BAR DIAGNOSTIC: report the real insets Flutter received on a
    // notched device. 0 here means Android is not forwarding window insets and
    // SafeArea has nothing to work with (native-layer issue, not a widget one).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final media = MediaQuery.of(context);
      final view = View.of(context);
      debugPrint(
        '[STATUS_BAR] safePaddingTop=${media.padding.top} '
        'viewPaddingTop=${view.padding.top} '
        'viewPaddingLeft=${view.padding.left} '
        'viewPaddingRight=${view.padding.right} '
        'dpr=${view.devicePixelRatio} size=${media.size}',
      );
    });
  }

  /// Loads whether the one-time sheet scroll hint has already been shown.
  Future<void> _loadSheetSwipeHintState() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_sheetSwipeHintKey) ?? false;
    if (mounted && _sheetSwipeHintVisible != !alreadyShown) {
      setState(() => _sheetSwipeHintVisible = !alreadyShown);
    }
  }

  /// Marks the scroll hint as seen (persisted) so it never resurfaces.
  Future<void> _dismissSheetSwipeHint() async {
    if (!_sheetSwipeHintVisible) return;
    setState(() => _sheetSwipeHintVisible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sheetSwipeHintKey, true);
  }

  /// Attaches a one-shot listener that persists + hides the scroll hint as
  /// soon as the user actually drags the sheet (content scrolls past 1px).
  void _attachSheetDragListener(ScrollController controller) {
    if (!_sheetSwipeHintVisible || _sheetDragListenerAttached) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sheetSwipeHintVisible || _sheetDragListenerAttached) return;
      if (!controller.hasClients) return;
      _sheetDragListenerAttached = true;
      controller.addListener(_handleSheetScrolled);
    });
  }

  void _handleSheetScrolled() {
    if (!_sheetSwipeHintVisible) return;
    final controller = _sheetScrollController;
    if (controller != null && controller.offset > 1) {
      _dismissSheetSwipeHint();
    }
  }

  /// Keeps the status bar icons legible against the map style: dark icons over
  /// the light (day) map, light icons over the dark (night) map. The map stays
  /// edge-to-edge, so only the overlay style is set here — not a safe-area.
  void _syncSystemUiOverlay(bool isDark) {
    if (_overlayStyleSyncedForDark == isDark) return;
    _overlayStyleSyncedForDark = isDark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ));
  }

  void _wireProximityAlerts() {
    _proximitySubscription = _activeJourneyVM.proximityEvents.listen((event) {
      if (!mounted) return;
      final settings = context.read<SettingsService>();
      if (settings.notificationsEnabled) {
        ArrivalAlertModal.showBanner(context, event);
      }
      if (settings.voiceGuidanceEnabled) {
        _ttsService.speak(event.displayMessage);
      }
    });
  }

  /// Persists a true trip completion (arrival) as a journey-history record
  /// that drives the Settings/Profile stats. Cancelled trips never fire it.
  void _wireJourneyCompletion() {
    _activeJourneyVM.onJourneyCompleted = (record) {
      if (mounted) context.read<SettingsService>().addJourneyRecord(record);
    };
  }

  bool _lastHighAccuracyMode = true;

  void _syncHighAccuracy() {
    final settings = context.read<SettingsService>();
    if (settings.highAccuracyMode == _lastHighAccuracyMode) return;
    _lastHighAccuracyMode = settings.highAccuracyMode;
    context
        .read<NavigationProvider>()
        .reconfigurePositionStream(highAccuracy: settings.highAccuracyMode);
    // The live journey stream is fixed at creation time too — restart it so
    // the new accuracy applies immediately, not just on the next trip.
    if (_activeJourneyVM.isJourneyActive) {
      _activeJourneyVM.reconfigurePositionStream();
    }
  }

  void _loadSavedDestinations() {
    final settings = context.read<SettingsService>();
    final items = <SavedDestination>[];
    final home = settings.savedPlace(SavedPlaceKind.home);
    if (home != null && !home.isEmpty) {
      items.add(SavedDestination(
        id: 'home',
        label: home.label,
        latitude: home.lat,
        longitude: home.lng,
        type: SavedDestinationType.home,
      ));
    }
    final work = settings.savedPlace(SavedPlaceKind.work);
    if (work != null && !work.isEmpty) {
      items.add(SavedDestination(
        id: 'work',
        label: work.label,
        latitude: work.lat,
        longitude: work.lng,
        type: SavedDestinationType.work,
      ));
    }
    final campus = settings.savedPlace(SavedPlaceKind.campus);
    if (campus != null && !campus.isEmpty) {
      items.add(SavedDestination(
        id: 'campus',
        label: campus.label,
        latitude: campus.lat,
        longitude: campus.lng,
        type: SavedDestinationType.campus,
      ));
    }
    if (mounted) setState(() => _savedDestinations = items);
  }

  void _initNavigation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationPermission();
    });
  }

  @override
  void dispose() {
    _proximitySubscription?.cancel();
    _stagesSubscription?.cancel();
    _placesSubscription?.cancel();
    _locationFixTimer?.cancel();
    _locationStageTimer?.cancel();
    ArrivalAlertModal.dispose();
    _activeJourneyVM.dispose();
    _ttsService.dispose();
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

  void _showStageDetails(StageModel stage, {Position? userPosition}) {
    final userLatLng = userPosition != null
        ? LatLng(userPosition.latitude, userPosition.longitude)
        : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StageDetailsSheet(
        stage: stage,
        userLocation: userLatLng,
        onNavigate: () => _startNavigation(stage.name, stage.location),
      ),
    );
  }

  void _onAddFavorite(SavedDestinationType type) {
    showDialog(
      context: context,
      builder: (ctx) => SavedDestinationDialog(type: type),
    ).then((_) => _loadSavedDestinations());
  }

  void _startNavigation(String destination, LatLng point) {
    if (point.latitude == 0 && point.longitude == 0) return;
    final settings = context.read<SettingsService>();
    context.read<NavigationProvider>().setRoutingPreferences(
          avoidBusyJunctions: settings.avoidBusyJunctions,
          preferWalkingPaths: settings.preferWalkingPaths,
          highAccuracyMode: settings.highAccuracyMode,
        );
    context.read<NavigationProvider>().startNavigation(destination, point);
    final nav = context.read<NavigationProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (nav.routePolyline.isNotEmpty) _fitRouteOnMap(nav.routePolyline);
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
  ) {
    _mapManager.clearAll();
    if (routePolyline.isNotEmpty || remainingRoute.isNotEmpty) {
      // The PolylineRendererService has rendered (or will render) the
      // journey line — both for a confirmed pre-trip preview (segmented
      // dashed/solid polyline) and during active navigation. The raw OSRM
      // route is only drawn when no renderer-owned journey is on screen,
      // otherwise its single-colour line overlaps the stitched route.
      final rendererOwnsLine =
          _confirmedJourney != null || journey.isActive;
      if (!rendererOwnsLine) {
        MapboxLayers.setRoutePolylines(
          _mapManager,
          remainingRoute.isNotEmpty ? remainingRoute : routePolyline,
          traveledPoints: traveledRoute,
          color: const Color(0xFF1E88E5),
        );
      }
    }
    if (endPoint != null) {
      MapboxLayers.addDestinationMarker(_mapManager, endPoint);
    }
    // NOTE: no manual user-location circle here anymore — the native Mapbox
    // location component (pulsing signal-blue puck with accuracy ring, enabled
    // via onStyleLoadedListener) now provides the live position indicator.
    MapboxLayers.addStageMarkers(_mapManager, _allStages);
    MapboxLayers.addPlaceMarkers(_mapManager, _places);
    if (journey.isActive) {
      JourneyMapLayers.applyToMap(
        manager: _mapManager,
        journey: journey,
        userLocation: currentPosition != null
            ? LatLng(currentPosition.latitude, currentPosition.longitude)
            : null,
        destinationPoint: endPoint,
        drawPaths: !_polylineRendererOwnsActiveRoute,
      );
    }
  }

  void _startJourney(NavigationProvider nav, JourneyProvider journey) async {
    if (nav.selectedPath == null || nav.endPoint == null) return;
    final path = nav.selectedPath!;
    final stopNames =
        path.path.where((n) => n.type == 'stage').map((n) => n.name).toList();
    final primaryRoute =
        path.routeNumbers.isNotEmpty ? path.routeNumbers.first : 'N/A';

    // Also start the legacy journey provider for backward compatibility
    journey.startJourney(
      destinationName: nav.endName ?? 'Destination',
      destinationPoint: nav.endPoint!,
      fromStageName:
          path.path.isNotEmpty ? path.path.first.name : nav.currentStreet,
      fromStageId: path.path.isNotEmpty ? path.path.first.id : '',
      fromStageLocation:
          path.path.isNotEmpty ? path.path.first.location : nav.endPoint!,
      toStageName:
          path.path.isNotEmpty ? path.path.last.name : nav.endName ?? '',
      toStageId: path.path.isNotEmpty ? path.path.last.id : '',
      toStageLocation:
          path.path.isNotEmpty ? path.path.last.location : nav.endPoint!,
      routeNumber: primaryRoute,
      routeName: primaryRoute,
      estimatedFare: path.totalFare,
      estimatedDuration: (path.totalTime / 60).round(),
      stopNames: stopNames,
    );

    // Build and start the new active journey with polyline rendering
    final userPos = nav.currentPosition;
    if (userPos != null) {
      final origin = LatLng(userPos.latitude, userPos.longitude);
      final destination = SearchResult(
        query: nav.endName ?? 'Destination',
        lat: nav.endPoint!.latitude,
        lng: nav.endPoint!.longitude,
        resolvedLabel: nav.endName ?? 'Destination',
        matchedCorridorName:
            path.path.isNotEmpty && path.path.first is StageModel
                ? (path.path.first as StageModel).corridor
                : null,
        nearestStageName: path.path.isNotEmpty
            ? path.path.last.name
            : nav.endName ?? 'Destination',
        nearestStageLat: nav.endPoint!.latitude,
        nearestStageLng: nav.endPoint!.longitude,
        routeNumbers: path.routeNumbers,
        distanceToStageMeters: 0.0,
        source: SearchResultSource.exactStage,
      );

      if (_confirmedJourney != null) {
        // The confirmed route was already built for the pre-trip overview —
        // reuse it instead of recomputing the same journey a second time.
        await _activeJourneyVM.startJourneyWith(
          _confirmedJourney!,
          originLabel: nav.currentStreet,
          destinationLabel: nav.endName,
        );
      } else {
        final settings = context.read<SettingsService>();
        await _activeJourneyVM.startJourney(
          origin: origin,
          destination: destination,
          preferWalkingPaths: settings.preferWalkingPaths,
          avoidBusyJunctions: settings.avoidBusyJunctions,
          originLabel: nav.currentStreet,
          destinationLabel: nav.endName,
        );
      }
    }

    setState(() => _showJourneyPanel = true);
  }

  /// Builds the single confirmed-route object for the pre-trip overview.
  ///
  /// Runs exactly once per (destination, route) selection (keyed by
  /// [_confirmedRouteKey]) after the provider has produced a [PathOption], and
  /// both renders the segmented dashed-green/solid-blue polyline and feeds the
  /// top summary card and bottom metrics row — one source of truth.
  Future<void> _ensureConfirmedRoute(
      NavigationProvider nav, PathOption path) async {
    final endPoint = nav.endPoint;
    final userPos = nav.currentPosition;
    if (endPoint == null || userPos == null) return;

    final routeSignature =
        path.routeNumbers.isNotEmpty ? path.routeNumbers.join('|') : 'walk';
    final key =
        '${endPoint.latitude.toStringAsFixed(5)},${endPoint.longitude.toStringAsFixed(5)}#$routeSignature';
    if (_confirmedRouteKey == key) return;

    try {
      final settings = context.read<SettingsService>();
      final journey = await RouteBuilderService.build(
        origin: LatLng(userPos.latitude, userPos.longitude),
        destination: SearchResult(
          query: nav.endName ?? 'Destination',
          lat: endPoint.latitude,
          lng: endPoint.longitude,
          resolvedLabel: nav.endName ?? 'Destination',
          matchedCorridorName:
              path.path.isNotEmpty && path.path.first is StageModel
                  ? (path.path.first as StageModel).corridor
                  : (path.routeNumbers.isNotEmpty
                      ? path.routeNumbers.first
                      : null),
          nearestStageName: path.path.isNotEmpty
              ? path.path.last.name
              : (nav.endName ?? 'Destination'),
          nearestStageLat: endPoint.latitude,
          nearestStageLng: endPoint.longitude,
          routeNumbers: path.routeNumbers,
          distanceToStageMeters: 0.0,
          source: SearchResultSource.exactStage,
        ),
        preferWalkingPaths: settings.preferWalkingPaths,
        avoidBusyJunctions: settings.avoidBusyJunctions,
      );
      if (!mounted) return;
      setState(() {
        _confirmedJourney = journey;
        _confirmedRouteKey = key;
      });
      _fitRouteOnMap([
        for (final segment in journey.segments)
          ...segment.coordinates,
      ]);
      await _polylineRenderer.renderJourney(journey, preview: true);
    } catch (e) {
      debugPrint('[NAV] Confirmed route build failed: $e');
      if (!mounted) return;
      // Mark the key so we never retry the same route; the overview falls
      // back to the provider's PathOption preview.
      setState(() => _confirmedRouteKey = key);
    }
  }

  void _recenterOnUser(NavigationProvider nav) {
    final pos = nav.currentPosition;
    if (pos == null) return;
    final userLatLng = LatLng(pos.latitude, pos.longitude);
    if (!_isWithinNairobi(pos.latitude, pos.longitude)) {
      _mapManager.flyTo(userLatLng, zoom: _navigationZoom);
      _showOutOfBoundsDialog();
    } else {
      _mapManager.flyTo(userLatLng, zoom: _navigationZoom);
    }
  }

  void _showOutOfBoundsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Outside NaVi Area'),
          ],
        ),
        content: const Text(
          'You are currently outside NaVi\'s Nairobi operational area. '
          'You can still view your current position and track your coordinates, '
          'but routing and transit stage metrics will remain focused within Nairobi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    _syncSystemUiOverlay(settings.isDarkTheme);
    return ChangeNotifierProvider<ActiveJourneyViewModel>.value(
      value: _activeJourneyVM,
      child: Consumer2<NavigationProvider, JourneyProvider>(
        builder: (context, nav, journey, child) {
          final currentPosition = nav.currentPosition;
          final endPoint = nav.endPoint;
          final routePolyline = nav.routePolyline;
          final traveledRoute = nav.traveledRoute;
          final remainingRoute = nav.remainingRoute;
          final selectedPath = nav.selectedPath;
          final pathOptions = nav.pathOptions;
          final isNavigating = nav.isNavigating;

          final showPreTripBar = isNavigating &&
              selectedPath != null &&
              !_showJourneyPanel &&
              !_showSearch;
          final preTripSummary =
              _preTripSummary(selectedPath, _confirmedJourney);

          // The Active Navigation screen replaces the whole body once a live
          // journey exists — both while navigating and after arrival (the
          // "Arrived" state keeps End Trip available). Cancelling the journey
          // nulls activeJourney, which flips this back to the normal map.
          final showActiveNav =
              _showJourneyPanel && _activeJourneyVM.activeJourney != null;

          if (nav.hasArrived) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _showArrivalDialog(nav));
          }

          WidgetsBinding.instance
              .addPostFrameCallback((_) => _syncHighAccuracy());

          // Build the single confirmed-route object exactly once per
          // (destination, selected route) once the provider has a path.
          if (isNavigating && selectedPath != null && !_showJourneyPanel) {
            final endPoint = nav.endPoint;
            if (endPoint != null) {
              final routeSignature = selectedPath.routeNumbers.isNotEmpty
                  ? selectedPath.routeNumbers.join('|')
                  : 'walk';
              final expectedKey =
                  '${endPoint.latitude.toStringAsFixed(5)},${endPoint.longitude.toStringAsFixed(5)}#$routeSignature';
              if (_confirmedRouteKey != expectedKey) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _ensureConfirmedRoute(nav, selectedPath);
                });
              }
            }
          }

          // Drop the confirmed route once navigation is cancelled.
          if (!isNavigating &&
              (_confirmedJourney != null || _confirmedRouteKey != null)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _polylineRenderer.clearJourney();
              setState(() {
                _confirmedJourney = null;
                _confirmedRouteKey = null;
              });
            });
          }

          return HomepageEntranceAnimation(
            builder: (context, mapAnim, topAnim, sheetAnim) {
              final topSlide = Tween<Offset>(
                begin: const Offset(0, -1),
                end: Offset.zero,
              ).animate(topAnim);

              return Scaffold(
                backgroundColor: NaviColors.canvas(
                    Theme.of(context).brightness == Brightness.dark),
                bottomNavigationBar:
                    showPreTripBar && preTripSummary != null
                        ? _buildPreTripBottomBar(
                            selectedPath, preTripSummary)
                        : null,
                body: showActiveNav
                    ? NavigationOverlay(
                        map: Stack(
                          children: [
                            Positioned.fill(
                              child: _buildMapZoneWidget(
                                context,
                                settings,
                                nav,
                                journey,
                                currentPosition,
                                endPoint,
                                routePolyline,
                                traveledRoute,
                                remainingRoute,
                                mapAnim,
                                isJourneyActive:
                                    _activeJourneyVM.isJourneyActive,
                              ),
                            ),
                            _buildMapControls(
                              context,
                              nav,
                              mapAnim,
                              top:
                                  MediaQuery.of(context).padding.top + 96,
                            ),
                          ],
                        ),
                        journey: _activeJourneyVM.activeJourney!,
                        voiceGuidanceEnabled:
                            settings.voiceGuidanceEnabled,
                        onToggleVoiceGuidance:
                            settings.setVoiceGuidanceEnabled,
                        onEndTrip: _endActiveTrip,
                      )
                    : Stack(
                        children: [
                          // --- FULL-SCREEN MAP (entrance: fades in first) ---
                          _buildMapZoneWidget(
                            context,
                            settings,
                            nav,
                            journey,
                            currentPosition,
                            endPoint,
                            routePolyline,
                            traveledRoute,
                            remainingRoute,
                            mapAnim,
                            isJourneyActive: false,
                          ),

                // --- TOP FLOATING BAR (Search + Settings + Profile) + QUICK GO ---
                // Rebuild keeps the existing search-bar functional logic
                // (`_buildTopBar`); Quick Go chips are promoted from the sheet
                // area to sit directly beneath the search bar. Entrance:
                // slides down from above with the search bar + chips.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SlideTransition(
                    position: topSlide,
                    child: FadeTransition(
                      opacity: topAnim,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTopBar(context, nav),
                              if (!isNavigating &&
                                  !_showSearch &&
                                  currentPosition != null) ...[
                                const SizedBox(height: _quickGoGap),
                                QuickGoRow(
                                  destinations: _savedDestinations,
                                  onTap: (dest) {
                                    _startNavigation(
                                        dest.label,
                                        LatLng(dest.latitude, dest.longitude));
                                  },
                                  onEdit: (dest) =>
                                      _onAddFavorite(dest.type),
                                  onAddHome:
                                      _savedDestinations.any((d) =>
                                              d.type ==
                                              SavedDestinationType.home)
                                          ? null
                                          : () => _onAddFavorite(
                                              SavedDestinationType.home),
                                  onAddWork:
                                      _savedDestinations.any((d) =>
                                              d.type ==
                                              SavedDestinationType.work)
                                          ? null
                                          : () => _onAddFavorite(
                                              SavedDestinationType.work),
                                  onAddCampus:
                                      _savedDestinations.any((d) =>
                                              d.type ==
                                              SavedDestinationType.campus)
                                          ? null
                                          : () => _onAddFavorite(
                                              SavedDestinationType.campus),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // --- SEARCH OVERLAY ---
                if (_showSearch)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).size.height * 0.4,
                    child: _buildSearchSection(context, nav),
                  ),

                // --- MAP CONTROL BUTTONS (right side) ---
                _buildMapControls(
                  context,
                  nav,
                  mapAnim,
                  top: MediaQuery.of(context).padding.top +
                      (isNavigating || _showSearch
                          ? 72
                          : _topBarHeight + _quickGoGap + _quickGoHeight + 8),
                ),

                // --- PRE-TRIP SUMMARY CARD (top; bound to the confirmed
                // route's single summary object — same numbers as the bottom
                // metrics row, never the OSRM driving preview) ---
                if (showPreTripBar && preTripSummary != null && nav.endName != null)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 72,
                    left: 16,
                    right: 16,
                    child: FadeTransition(
                      opacity: mapAnim,
                      child: _buildTripSummaryHeader(
                        nav.endName!,
                        preTripSummary,
                        routeLabel: selectedPath.routeNumbers.isNotEmpty
                            ? selectedPath.routeNumbers.first
                            : null,
                      ),
                    ),
                  ),

                // --- BOTTOM SHEET (entrance: slides up from below) ---
                if (!_showJourneyPanel)
                  _buildBottomSheet(
                    context,
                    nav,
                    journey,
                    currentPosition,
                    selectedPath,
                    pathOptions,
                    settings,
                    sheetAnim,
                    preTripSummary,
                  ),

                // --- CURRENT STREET LABEL (top-left corner) ---
                if (currentPosition != null && !isNavigating)
                  Positioned(
                    top: MediaQuery.of(context).padding.top +
                        (currentPosition != null ? 120 : 72),
                    left: 16,
                    child: FadeTransition(
                      opacity: mapAnim,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: NaviColors.surface(
                                  Theme.of(context).brightness == Brightness.dark)
                              .withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.my_location, color: Colors.blue, size: 14),
                            const SizedBox(width: 4),
                            Text(nav.currentStreet,
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
            },
          );
        },
      ),
    );
  }

  // ============== TOP BAR ==============

  Widget _buildTopBar(BuildContext context, NavigationProvider nav) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      color: NaviColors.surface(
          Theme.of(context).brightness == Brightness.dark),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: _SearchBarButton(
                hint: nav.isNavigating && nav.endName != null
                    ? nav.endName!
                    : 'Where are you going?',
                emphasized: nav.isNavigating && nav.endName != null,
                onPressed: () {
                  setState(() => _showSearch = !_showSearch);
                  nav.setShowSearch(_showSearch);
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              color: AppConstants.nairobiGreen,
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline),
              color: AppConstants.nairobiGreen,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a loading state that swaps to retry on timeout, to the
  /// permission-request card on denial, or to the live hero card on a fix.
  Future<void> _requestLocationPermission() async {
    if (_locationRequestRunning) return;
    // NavigationProvider outlives this State, so capture it up front and
    // never touch `context` across an await without a mounted guard.
    final nav = context.read<NavigationProvider>();
    _locationRequestRunning = true;
    _locationStageTimer?.cancel();
    setState(() {
      _locationTimedOut = false;
      _locationDenied = false;
    });

    // Irrevocably denied never resolves on its own — go straight to the
    // permission-request card instead of sitting in a loading state.
    final prePermission = await Geolocator.checkPermission();
    if (!mounted) {
      _locationRequestRunning = false;
      return;
    }
    if (prePermission == LocationPermission.deniedForever) {
      setState(() {
        _locationDenied = true;
      });
      _locationRequestRunning = false;
      return;
    }

    // The timeout fires while the fix is pending; if no position has arrived
    // by then, swap the shimmer for the actionable retry card.
    _locationFixTimer = Timer(_locationFixTimeout, () {
      if (!mounted) return;
      if (nav.currentPosition == null) {
        setState(() {
          _locationTimedOut = true;
        });
      }
    });

    await nav
        .initializeLocation()
        .timeout(_locationFixTimeout + const Duration(seconds: 2),
            onTimeout: () {});
    _locationFixTimer?.cancel();
    if (!mounted) return;

    final permission = await Geolocator.checkPermission();
    if (!mounted) return;
    final denied = permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever;
    final gpsResolved = nav.currentPosition != null;

    // Brief staged beat: once GPS resolves (but the stage match is being
    // computed), show "Finding nearby stages…" before the live card lands so
    // the wait reads as two distinct steps.
    if (gpsResolved && !denied) {
      setState(() => _showStageLookup = true);
      _locationStageTimer?.cancel();
      _locationStageTimer = Timer(_stageLookupTransition, () {
        if (!mounted) return;
        setState(() {
          _showStageLookup = false;
        });
      });
    } else {
      setState(() {
        _locationDenied = denied;
        // Granted permission but no fix (fast error path, e.g. GPS off) is
        // still the "check your GPS signal" state, never a silent shuffle back
        // to the permission prompt.
        _locationTimedOut = !denied && !gpsResolved ? true : _locationTimedOut;
      });
    }
    _locationRequestRunning = false;

    if (!denied) {
      await _mapManager.enableLocation();
    }
  }

  /// The sorted-by-distance stage list feeding both the hero card and the
  /// revealed-on-drag list. The nearest stage is the first element — exposed
  /// as a single value by taking `entries.first`, not by a list.
  List<NearbyStageEntry> _nearbyStageEntries(Position? currentPosition) {
    final stages = _allStages.isNotEmpty ? _allStages : SeedData.getStages();
    final entries = stages
        .map((stage) => NearbyStageEntry(
              stage: stage,
              distanceMeters: currentPosition != null
                  ? DistanceCalculator.distanceMeters(
                      LatLng(currentPosition.latitude,
                          currentPosition.longitude),
                      LatLng(stage.lat, stage.lng),
                    )
                  : 0.0,
            ))
        .toList();
    if (currentPosition != null) {
      entries.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    }
    return entries;
  }

  /// "12 min walk" label for the hero card, derived from the single shared
  /// walking-speed constant in [DistanceCalculator].
  String _walkTimeLabelFor(double distanceMeters) {
    final seconds = DistanceCalculator.walkDurationForDistance(distanceMeters);
    return '${max(1, (seconds / 60).round())} min walk';
  }

  Widget _buildSearchSection(BuildContext context, NavigationProvider nav) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: SearchOverlay(
        isTransportMode: true,
        userPosition: nav.currentPosition != null
            ? LatLng(nav.currentPosition!.latitude,
                nav.currentPosition!.longitude)
            : null,
        onSelectDestination: (name, point) {
          setState(() => _showSearch = false);
          _startNavigation(name, point);
        },
        onClose: () {
          setState(() => _showSearch = false);
          nav.setShowSearch(false);
        },
      ),
    );
  }

  // ============== BOTTOM SHEET ==============

  Widget _buildBottomSheet(
    BuildContext context,
    NavigationProvider nav,
    JourneyProvider journey,
    Position? currentPosition,
    PathOption? selectedPath,
    List<PathOption> pathOptions,
    SettingsService settings,
    Animation<double> sheetAnimation,
    _PreTripSummary? summary,
  ) {
    final nearbyEntries = _nearbyStageEntries(currentPosition);
    final heroEntry = currentPosition != null &&
            nearbyEntries.isNotEmpty &&
            nearbyEntries.first.distanceMeters <= _nearbyRangeMeters
        ? nearbyEntries.first
        : null;
    final remainingStages =
        heroEntry == null ? <NearbyStageEntry>[] : nearbyEntries.skip(1).toList();

    // Exactly one hero slot contender. Resolution order:
    // 1. Permission is the blocker       → permission-request card
    //    (short-circuits immediately; never a loading shimmer).
    // 2. GPS fix timed out (~8s)         → "still finding your location"
    //    retry card, never infinite shimmer.
    // 3. GPS resolved, brief stage-lookup beat → "Finding nearby stages…"
    //    shown before the live card lands (set BEFORE the live-card branch so
    //    the transition is visible rather than flashing straight through).
    // 4. GPS fix + nearest stage found  → live [HeroGoCard].
    // 5. GPS fix, no stage in range      → informatively empty card.
    // 6. GPS still resolving             → phased shimmer that names the wait
    //    ("Getting your location…").
    Widget heroCard;
    if (_locationDenied) {
      heroCard = HeroGoCardPlaceholder(
        onEnableLocation: _requestLocationPermission,
      );
    } else if (_locationTimedOut) {
      heroCard = HeroGoCardLocationTimeout(
        onRetry: _requestLocationPermission,
      );
    } else if (_showStageLookup) {
      heroCard = HeroGoCardLoading(phase: HeroGoLoadPhase.findingStages);
    } else if (currentPosition != null && heroEntry != null) {
      heroCard = HeroGoCard(
        labelTitle: 'Nearest stage',
        stageName: heroEntry.stage.name,
        distanceLabel:
            '${DistanceFormatter.format(heroEntry.distanceMeters)} away',
        walkTimeLabel: _walkTimeLabelFor(heroEntry.distanceMeters),
        routeNumbers: heroEntry.stage.routes,
        onTap: () =>
            _showStageDetails(heroEntry.stage, userPosition: currentPosition),
      );
    } else if (currentPosition != null) {
      heroCard = const HeroGoCardEmptyState();
    } else {
      heroCard = HeroGoCardLoading(phase: HeroGoLoadPhase.locating);
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      top: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(sheetAnimation),
        child: FadeTransition(
          opacity: sheetAnimation,
          child: DraggableScrollableSheet(
            initialChildSize:
                nav.isNavigating && nav.endName != null ? 0.35 : 0.22,
            minChildSize: 0.22,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) {
              _sheetScrollController = scrollController;
              _attachSheetDragListener(scrollController);
              return Container(
                decoration: BoxDecoration(
                  color: NaviColors.canvas(
                      Theme.of(context).brightness == Brightness.dark),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // Drag Handle
                    const _DragHandle(),
                    if (_sheetSwipeHintVisible) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 10),
                        child: Center(
                          child:
                              Text('Swipe up for more stages',
                                  style: NaviType.caption.copyWith(
                                      color: NaviColors.textSecondary(
                                          Theme.of(context).brightness ==
                                              Brightness.dark))),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 12),
                    if (nav.isNavigating && nav.endName != null) ...[
                      // CONFIRMED-DESTINATION state: nearby-stage alternatives
                      // are intentionally NOT offered here — the destination is
                      // already chosen. Alternatives belong on the home hero,
                      // pre-selection, only.
                      _buildDestinationHeader(nav, settings, summary),
                      const SizedBox(height: 12),
                      if (selectedPath != null)
                        _buildRouteCard(nav, journey, settings, summary),
                      if (pathOptions.length > 1)
                        _buildOtherRoutes(pathOptions, nav),
                    ] else ...[
                      heroCard,
                      // The nearby list only makes sense when a stage was in
                      // range; otherwise the empty-state card explains itself.
                      if (heroEntry != null) ...[
                        const SizedBox(height: 20),
                        Text('Nearby stages',
                            style: NaviType.cardTitle.copyWith(
                                color: NaviColors.textPrimary(
                                    Theme.of(context).brightness ==
                                        Brightness.dark))),
                        NearbyStagesList(
                          stages: remainingStages,
                          onStageTap: (s) => _showStageDetails(s,
                              userPosition: currentPosition),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildPopularDestinations(context),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ============== PRE-TRIP CONFIRMED-ROUTE SUMMARY ==============

  /// Builds the single metrics object for the confirmed route. Both the top
  /// summary card and the bottom metrics row are rendered from the ONE
  /// [_PreTripSummary] returned here, so they can never disagree — regardless
  /// of whether the confirmed [ActiveJourney] was built (real walk/ride split)
  /// or the provider's [PathOption] fallback applies.
  _PreTripSummary? _preTripSummary(
      PathOption? path, ActiveJourney? journey) {
    if (path == null) return null;

    if (journey != null) {
      final matatuSegments =
          journey.segments.where((s) => s.mode == SegmentMode.matatu).toList();
      return _PreTripSummary(
        walkDistanceMeters: journey.walkDistanceMeters,
        walkDuration: journey.walkDuration,
        matatuDuration: journey.matatuDuration,
        totalDuration: journey.totalEstimatedDuration,
        matatuLegs: matatuSegments.length,
        fareKsh: journey.fareTotalKsh,
        hasConfirmedRoute: true,
      );
    }

    final hasVehicleLeg = path.edges.any((e) => !e.routeNumbers.contains('walk'));
    return _PreTripSummary(
      walkDistanceMeters: path.totalDistance,
      walkDuration: Duration(minutes: path.totalTime),
      matatuDuration: Duration(minutes: path.totalTime),
      totalDuration: Duration(minutes: path.totalTime),
      matatuLegs: hasVehicleLeg ? path.edges.length : 0,
      fareKsh: _guardFare(path.totalFare.round(), hasVehicleLeg: hasVehicleLeg),
      hasConfirmedRoute: false,
    );
  }

  /// A matatu-inclusive trip is never free — only pure-walking is KSh 0. This
  /// guards the PathOption fallback path (which can carry graph-edge fares of
  /// zero); the confirmed-journey fares already go through
  /// [FareCalculatorService] where matatu legs are floor-guarded.
  int _guardFare(int fare, {required bool hasVehicleLeg}) {
    if (hasVehicleLeg && fare <= 0) return 20;
    return fare;
  }

  /// Bottom-docked pre-trip bar, hosted by [Scaffold.bottomNavigationBar] so it
  /// is structurally pinned to the screen bottom by the layout (not a
  /// [Positioned] float that can drift toward the middle of the map).
  Widget _buildPreTripBottomBar(PathOption path, _PreTripSummary summary) {
    final nav = context.read<NavigationProvider>();
    final journeyProvider = context.read<JourneyProvider>();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: NaviColors.canvas(
              Theme.of(context).brightness == Brightness.dark),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryChips(summary: summary),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startJourney(nav, journeyProvider),
                icon: const Icon(Icons.navigation,
                    color: Colors.white, size: 20),
                label: Text(
                  'Start Journey — ${summary.totalTimeLabel} · ${summary.fareLabel}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NaviColors.transitGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top summary card, reading the SAME [_PreTripSummary] as the bottom bar.
  Widget _buildTripSummaryHeader(
    String destinationName,
    _PreTripSummary summary, {
    String? routeLabel,
  }) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      color: NaviColors.surface(
          Theme.of(context).brightness == Brightness.dark),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    destinationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if (routeLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: NaviColors.psvYellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Route $routeLabel',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _SummaryChips(summary: summary),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationHeader(
      NavigationProvider nav, SettingsService settings, _PreTripSummary? summary) {
    return Card(
      elevation: 0,
      color: NaviColors.surface(
          Theme.of(context).brightness == Brightness.dark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nav.endName ?? 'Destination',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap "Start Journey" to begin',
                    style: TextStyle(
                        color: NaviColors.textSecondary(
                            Theme.of(context).brightness == Brightness.dark),
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            // Metrics come from the SAME confirmed-route summary as the top
            // card and the bottom bar — never an independent path value.
            if (summary != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(summary.fareLabel,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.nairobiGreen)),
                  Text(summary.totalTimeLabel,
                      style: TextStyle(
                          color: NaviColors.textSecondary(
                              Theme.of(context).brightness == Brightness.dark),
                          fontSize: 12)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(NavigationProvider nav, JourneyProvider journey,
      SettingsService settings, _PreTripSummary? summary) {
    final path = nav.selectedPath!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppConstants.nairobiGreen.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RouteCardBadge(
                    label: path.routeNumbers.isNotEmpty
                        ? path.routeNumbers.first
                        : 'N/A'),
                const SizedBox(width: 8),
                RouteCardBadge(
                    label: summary?.fareLabel ?? path.formattedFare,
                    color: Colors.orange),
                const SizedBox(width: 8),
                RouteCardBadge(
                    label: summary?.totalTimeLabel ?? path.formattedTime,
                    color: Colors.blue),
              ],
            ),
            const SizedBox(height: 10),
            _buildRouteSteps(path),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSteps(PathOption path) {
    final steps = <Widget>[];
    final stopNames =
        path.path.where((n) => n.type == 'stage').map((n) => n.name).toList();
    if (stopNames.isNotEmpty) {
      steps.add(_routeStep('Board at ${stopNames.first}', Icons.directions_bus,
          AppConstants.nairobiGreen));
      if (stopNames.length > 2) {
        steps.add(Padding(
          padding: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
          child: Text('${stopNames.length - 2} stops via ${stopNames[1]}...',
              style: TextStyle(
                  color: NaviColors.textSecondary(
                      Theme.of(context).brightness == Brightness.dark),
                  fontSize: 12)),
        ));
      }
      if (stopNames.length > 1) {
        steps.add(
            _routeStep('Alight at ${stopNames.last}', Icons.flag, Colors.red));
      }
    }
    return Column(children: steps);
  }

  Widget _routeStep(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Text(label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildOtherRoutes(
      List<PathOption> pathOptions, NavigationProvider nav) {
    if (pathOptions.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Other routes',
              style: TextStyle(
                  color: NaviColors.textSecondary(
                      Theme.of(context).brightness == Brightness.dark),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: pathOptions.length - 1,
              itemBuilder: (context, i) {
                final option = pathOptions[i + 1];
                return GestureDetector(
                  onTap: () => nav.selectPathOption(option),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NaviColors.surface(
                          Theme.of(context).brightness == Brightness.dark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: NaviColors.dividerC(Theme.of(context).brightness == Brightness.dark)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            option.routeNumbers.isNotEmpty
                                ? option.routeNumbers.first
                                : 'N/A',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(option.formattedFare,
                            style: TextStyle(
                                color: NaviColors.textSecondary(
                                    Theme.of(context).brightness ==
                                        Brightness.dark),
                                fontSize: 11)),
                        Text(option.formattedTime,
                            style: TextStyle(
                                color: NaviColors.textSecondary(
                                    Theme.of(context).brightness ==
                                        Brightness.dark),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularDestinations(BuildContext context) {
    final popular = [
      'KICC',
      'Westlands',
      'JKIA',
      'Chiromo Campus',
      'Sarit Centre',
      'Roysambu'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.trending_up,
              size: 16,
              color: NaviColors.textSecondary(
                  Theme.of(context).brightness == Brightness.dark),
            ),
            const SizedBox(width: 4),
            Text('Popular Destinations',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: NaviColors.textPrimary(
                        Theme.of(context).brightness == Brightness.dark))),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: popular
              .map((name) => ActionChip(
                    avatar: const Icon(Icons.location_on,
                        size: 14, color: AppConstants.nairobiGreen),
                    label: Text(name, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _onPopularDestinationTap(name),
                  ))
              .toList(),
        ),
      ],
    );
  }

  void _onPopularDestinationTap(String name) {
    final stages = SeedData.getStages();
    final match = stages
        .where((s) =>
            s.name.toLowerCase().contains(name.toLowerCase()) ||
            s.corridor.toLowerCase().contains(name.toLowerCase()))
        .toList();
    if (match.isNotEmpty) {
      _startNavigation(match.first.name, match.first.location);
      return;
    }
    _popularDestinationGeocode(name);
  }

  Future<void> _popularDestinationGeocode(String name) async {
    final geocoder = GeocodingService();
    try {
      final results = await geocoder.geocodeMultiple(name, limit: 1);
      if (results.isNotEmpty) {
        final place = results.first;
        _startNavigation(place.placeName, place.coordinate);
      }
    } finally {
      geocoder.dispose();
    }
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
            Text(destName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Travel time: ${mins}m ${secs}s'),
            const Text('Well done, you made it!'),
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
              setState(() => _showSearch = true);
              nav.toggleSearch();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Navigate Again'),
          ),
        ],
      ),
    );
  }

  // ============== ACTIVE NAVIGATION SCREEN ==============

  /// The map widget (re)created on the Active Navigation screen. During live
  /// navigation the fresh map instance re-renders the journey polyline and
  /// flies to the user so the route survives the body swap and stays in view.
  Widget _buildMapZoneWidget(
    BuildContext context,
    SettingsService settings,
    NavigationProvider nav,
    JourneyProvider journey,
    Position? currentPosition,
    LatLng? endPoint,
    List<LatLng> routePolyline,
    List<LatLng> traveledRoute,
    List<LatLng> remainingRoute,
    Animation<double> mapAnim, {
    required bool isJourneyActive,
  }) {
    final activeJourneyVM = context.read<ActiveJourneyViewModel>();
    return FadeTransition(
      opacity: mapAnim,
      child: MapWidget(
        key: ValueKey("homeMap_${settings.isDarkTheme}"),
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
          _syncMapAnnotations(
            nav,
            journey,
            currentPosition,
            endPoint,
            routePolyline,
            traveledRoute,
            remainingRoute,
          );
          if (_confirmedJourney != null) {
            // A theme switch recreates the map style and wipes annotations;
            // re-apply the segmented pre-trip polyline (or leave it to the
            // live journey VM if the panel is already open).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _polylineRenderer.renderJourney(
                _confirmedJourney!,
                preview: !_showJourneyPanel,
              );
            });
          }
          if (isJourneyActive) {
            // The body swap built a fresh map instance; render the live
            // journey line again and follow the user's current position.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              activeJourneyVM.reRenderJourney();
            });
            if (currentPosition != null) {
              _mapManager.flyTo(
                LatLng(currentPosition.latitude, currentPosition.longitude),
                zoom: _navigationZoom,
              );
            }
          }
        },
        onStyleLoadedListener: (_) {
          // The location component needs a loaded style; the puck config is
          // applied here (not in onMapCreated) so Mapbox does not drop it.
          // Also refires after a dark/light theme switch recreates the style.
          _mapManager.enableLocation();
        },
      ),
    );
  }

  /// The right-side map controls (recenter / zoom), positioned at [top].
  Widget _buildMapControls(
    BuildContext context,
    NavigationProvider nav,
    Animation<double> mapAnim, {
    required double top,
  }) {
    return Positioned(
      top: top,
      right: 12,
      child: FadeTransition(
        opacity: mapAnim,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MapControlButton(
              icon: Icons.my_location,
              onPressed: () => _recenterOnUser(nav),
            ),
            const SizedBox(height: 6),
            MapControlButton(
              icon: Icons.add,
              onPressed: () {
                _currentZoom = (_currentZoom + 0.5).clamp(11.0, 19.0);
                _mapboxMap?.setCamera(CameraOptions(zoom: _currentZoom));
              },
            ),
            const SizedBox(height: 6),
            MapControlButton(
              icon: Icons.remove,
              onPressed: () {
                _currentZoom = (_currentZoom - 0.5).clamp(11.0, 19.0);
                _mapboxMap?.setCamera(CameraOptions(zoom: _currentZoom));
              },
            ),
            if (_locationDenied) ...[
              const SizedBox(height: 8),
              _LocationDeniedChip(
                onEnable: _requestLocationPermission,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Single exit path from live navigation (End Trip + banner close): stop the
  /// journey, clear navigation state and drop the Active Navigation screen
  /// back to the normal map.
  void _endActiveTrip() {
    _activeJourneyVM.cancelJourney();
    context.read<NavigationProvider>().clearNavigation();
    setState(() => _showJourneyPanel = false);
  }
}

// ============== HELPER WIDGETS ==============

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    // The pill is a visual affordance only; the 44dp-tall box makes the grab
    // region meet the minimum touch-target size. The muted grey reads more
    // like a handle than the near-invisible canvas divider.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      alignment: Alignment.center,
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: isDark ? NaviColors.dividerDark : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// The search-bar touch target in the top bar.
///
/// Replaces the old plain [GestureDetector] so the bar gains a visible
/// keyboard focus indicator (a focus ring around the search field) for
/// accessibility; the 44dp height is the touch target.
class _SearchBarButton extends StatefulWidget {
  final String hint;
  final bool emphasized;
  final VoidCallback onPressed;

  const _SearchBarButton({
    required this.hint,
    required this.emphasized,
    required this.onPressed,
  });

  @override
  State<_SearchBarButton> createState() => _SearchBarButtonState();
}

class _SearchBarButtonState extends State<_SearchBarButton> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.hint,
      child: Focus(
        focusNode: _focusNode,
        child: GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
            widget.onPressed();
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _focused ? NaviColors.signalBlue : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search,
                    color: NaviColors
                        .textSecondary(Theme.of(context).brightness == Brightness.dark),
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.emphasized
                          ? NaviColors.textPrimary(
                              Theme.of(context).brightness == Brightness.dark)
                          : NaviColors.textSecondary(
                              Theme.of(context).brightness == Brightness.dark),
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const MapControlButton(
      {super.key, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: FloatingActionButton(
        heroTag: null,
        mini: true,
        onPressed: onPressed,
        backgroundColor: NaviColors.surface(
            Theme.of(context).brightness == Brightness.dark),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppConstants.nairobiGreen, size: 20),
      ),
    );
  }
}

/// Inline prompt shown near the map controls when location permission is
/// denied, so the missing puck is explained and re-enabling is one tap away
/// instead of silently rendering a puck-less map.
class _LocationDeniedChip extends StatelessWidget {
  final VoidCallback? onEnable;

  const _LocationDeniedChip({this.onEnable});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Enable location for live position',
      child: Material(
        color: NaviColors.surface(
            Theme.of(context).brightness == Brightness.dark),
        elevation: 3,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onEnable,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.my_location,
                    size: 16, color: NaviColors.signalBlue),
                const SizedBox(width: 6),
                Text(
                  'Enable location',
                  style: NaviType.caption.copyWith(
                    color: AppConstants.nairobiGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RouteCardBadge extends StatelessWidget {
  final String label;
  final Color color;
  const RouteCardBadge(
      {super.key, required this.label, this.color = AppConstants.nairobiGreen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

// ============== PRE-TRIP SUMMARY HELPERS ==============

/// Immutable metrics for the confirmed pre-trip route. Both the top summary
/// card and the bottom metrics row are rendered from this ONE object so the
/// walk distance, ride time and fare can never show contradictory values.
class _PreTripSummary {
  final double walkDistanceMeters;
  final Duration walkDuration;
  final Duration matatuDuration;
  final Duration totalDuration;
  final int matatuLegs;
  final int fareKsh;
  final bool hasConfirmedRoute;

  const _PreTripSummary({
    required this.walkDistanceMeters,
    required this.walkDuration,
    required this.matatuDuration,
    required this.totalDuration,
    required this.matatuLegs,
    required this.fareKsh,
    required this.hasConfirmedRoute,
  });

  String get walkLabel {
    final minutes = max(1, (walkDuration.inSeconds / 60).round());
    return '${DistanceFormatter.format(walkDistanceMeters)} · $minutes min';
  }

  String get rideLabel {
    if (matatuLegs <= 0) return 'No ride';
    final d = matatuDuration > Duration.zero ? matatuDuration : totalDuration;
    return _formatDuration(d);
  }

  String get totalTimeLabel => _formatDuration(totalDuration);

  String get fareLabel => 'KSh $fareKsh';

  static String _formatDuration(Duration d) {
    final roundedMinutes = d.inMinutes + (d.inSeconds % 60 >= 30 ? 1 : 0);
    if (roundedMinutes < 60) return '$roundedMinutes min';
    final h = roundedMinutes ~/ 60;
    final m = roundedMinutes % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }
}

/// The three-metric row (walk · ride · fare) shared verbatim by the pre-trip
/// summary card and the bottom-docked bar — one source, identical values.
class _SummaryChips extends StatelessWidget {
  final _PreTripSummary summary;

  const _SummaryChips({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _summaryChip(
              Icons.directions_walk, summary.walkLabel, const Color(0xFF00875A)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryChip(
              Icons.directions_bus, summary.rideLabel, const Color(0xFF1E88E5)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryChip(
              Icons.attach_money, summary.fareLabel, NaviColors.transitGreen),
        ),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
