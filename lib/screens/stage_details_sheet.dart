import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import 'dart:math' show max;

// Fix imports - use navi_app
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/services/prediction_service.dart';
import 'package:navi_app/services/database_service.dart';
import 'package:navi_app/providers/app_state_provider.dart';
import 'package:navi_app/utils/constants.dart';
import 'package:navi_app/data/seed_data.dart';
import 'package:navi_app/services/distance_calculator.dart';
import 'package:navi_app/services/stage_route_summary.dart';
import 'package:navi_app/utils/distance_formatter.dart';
import 'package:navi_app/design/navi_colors.dart';
import 'package:navi_app/design/navi_typography.dart';
import 'package:navi_app/widgets/route_badge.dart';

class StageDetailsSheet extends StatefulWidget {
  final StageModel stage;
  final VoidCallback? onNavigate; // Callback for navigation

  /// The user's CURRENT live GPS position, passed down from the home screen's
  /// location stream. Both this sheet and the home screen compute distance
  /// from this same value so their numbers always agree.
  final LatLng? userLocation;

  const StageDetailsSheet({
    super.key,
    required this.stage,
    this.onNavigate, // Add this
    this.userLocation,
  });

  @override
  State<StageDetailsSheet> createState() => _StageDetailsSheetState();
}

class _StageDetailsSheetState extends State<StageDetailsSheet> {
  final DatabaseService _databaseService = DatabaseService();
  final PredictionService _predictionService = PredictionService();

  List<RouteModel> _routes = [];
  RouteModel? _selectedRoute;
  bool _isLoadingRoutes = true;
  bool _isLoadingPrediction = false;
  Map<String, dynamic>? _predictionResult;

  // GTFS-derived rows (route badge + destination) and the stage-level
  // frequency sentence, loaded from the imported routes.json bundle.
  List<StageRouteSummary> _routeSummaries = [];
  bool _isLoadingSummaries = true;
  String _frequencyText = StageRouteSummaries.noFrequencyText;

  /// Route rows are capped until the user explicitly asks for the full list —
  /// a stage can be served by 30+ GTFS routes and an unbounded wall of codes
  /// reads as noise rather than information.
  static const int _initialRouteRowCount = 6;
  bool _showAllRoutes = false;

  /// The route number of the row the user last tapped. Kept separately from
  /// [_selectedRoute] because GTFS summaries and the Firestore/seed route list
  /// do not always contain the same numbers — without this, tapping a GTFS-only
  /// route did nothing at all.
  String? _selectedSummaryNumber;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    final summaries = await StageRouteSummaries.loadForStage(widget.stage);
    final frequency = await StageRouteSummaries.loadStageFrequency(widget.stage);
    if (!mounted) return;
    setState(() {
      _routeSummaries = summaries;
      _frequencyText = frequency;
      _isLoadingSummaries = false;
    });
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _isLoadingRoutes = true;
    });

    try {
      final routes = await _databaseService.getRoutesByStage(widget.stage.id);
      
      setState(() {
        _routes = routes;
        _isLoadingRoutes = false;
        
        // Select first route by default if available
        if (_routes.isNotEmpty) {
          _selectedRoute = _routes.first;
          _selectedSummaryNumber = _routes.first.number;
          _loadPrediction(_routes.first);
        }
      });
    } catch (e) {
      print('Failed to load routes from Firestore: $e, using SeedData');
      final fallbackRoutes = SeedData.getRoutesForStage(widget.stage.id);
      setState(() {
        _routes = fallbackRoutes;
        _isLoadingRoutes = false;
        if (_routes.isNotEmpty) {
          _selectedRoute = _routes.first;
          _selectedSummaryNumber = _routes.first.number;
          _loadPrediction(_routes.first);
        }
      });
    }
  }

  Future<void> _loadPrediction(RouteModel route) async {
    setState(() {
      _isLoadingPrediction = true;
      _predictionResult = null;
    });

    try {
      final prediction = await _predictionService.getPredictedWait(
        stageId: widget.stage.id,
        routeId: route.id,
      );
      
      setState(() {
        _predictionResult = prediction;
        _isLoadingPrediction = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPrediction = false;
      });
    }
  }

  /// "How far + how long to walk" to this stage, computed from the SAME live
  /// position the home screen uses, via the single shared
  /// [DistanceCalculator]. No independent GPS fetch and no hardcoded fallback
  /// coordinate — so this sheet always agrees with the nearest-stage card.
  WalkDistanceResult? get _walkDistance {
    final user = widget.userLocation;
    if (user == null) return null;
    return DistanceCalculator.walkingDistanceAndTime(
      user,
      LatLng(widget.stage.lat, widget.stage.lng),
    );
  }

  void _navigateToSubmit() {
    // Capture the navigator before popping so the push uses the same (root)
    // instance after the sheet route is removed.
    final navigator = Navigator.of(context);
    navigator.pop(); // Close bottom sheet
    navigator.pushNamed(
      '/submit',
      arguments: widget.stage,
    );
  }

  void _selectRoute(RouteModel route) {
    setState(() {
      _selectedRoute = route;
    });
    _loadPrediction(route);
    
    // Update selected route in provider
    Provider.of<AppStateProvider>(context, listen: false).selectRoute(route);
  }

  void _handleNavigate() {
    Navigator.pop(context); // Close bottom sheet
    if (widget.onNavigate != null) {
      widget.onNavigate!();
    } else {
      print('Navigate pressed but no onNavigate callback provided');
    }
  }

  Widget _buildHeader() {
    final walk = _walkDistance;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.nairobiGreen,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.stage.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.stage.corridor,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (walk != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_walk, size: 16, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 4),
                  Text(
                    '${DistanceFormatter.format(walk.distanceMeters)} · ${max(1, (walk.walkDuration / 60).round())} min walk',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One tappable row per GTFS route serving this stage: the route number in
  /// the yellow PSV badge, then the destination(s) its directions headsign
  /// toward. When the GTFS bundle yields nothing for this stage (unknown or
  /// unreadable), fall back to the legacy Firestore/seed chips.
  Widget _buildRouteList() {
    if (_isLoadingSummaries) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_routeSummaries.isEmpty) {
      if (_isLoadingRoutes || _routes.isNotEmpty) {
        return _buildLegacyChips();
      }
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('No routes available for this stage'),
        ),
      );
    }

    final visibleSummaries = _showAllRoutes
        ? _routeSummaries
        : _routeSummaries.take(_initialRouteRowCount).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRouteListHeader(),
          const SizedBox(height: 10),
          for (final summary in visibleSummaries) _buildRouteRow(summary),
          if (_routeSummaries.length > _initialRouteRowCount)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    setState(() => _showAllRoutes = !_showAllRoutes),
                child: Text(
                  _showAllRoutes
                      ? 'Show fewer routes'
                      : 'Show all ${_routeSummaries.length} routes',
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Explains what the badge rows are before the user sees them, so a wall of
  /// route codes reads as "matatus that pass here" instead of noise.
  Widget _buildRouteListHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = _routeSummaries.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count == 1
              ? '1 matatu route stops here'
              : '$count matatu routes stop here',
          style: NaviType.body.copyWith(
            color: NaviColors.textPrimary(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'The code is the matatu number; the arrow is where it is heading. '
          'Tap a route to select it.',
          style: NaviType.caption.copyWith(
            color: NaviColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteRow(StageRouteSummary summary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedSummaryNumber == summary.routeNumber ||
        _selectedRoute?.number == summary.routeNumber;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppConstants.nairobiGreen.withValues(alpha: 0.08)
            : NaviColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppConstants.nairobiGreen
              : NaviColors.dividerC(isDark),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectRouteByNumber(summary.routeNumber),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              RouteBadge(routeNumber: summary.routeNumber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '→ ${summary.headsign}',
                  style: NaviType.body.copyWith(
                    color: NaviColors.textPrimary(isDark),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: NaviColors.textSecondary(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectRouteByNumber(String number) {
    for (final route in _routes) {
      if (route.number == number) {
        setState(() => _selectedSummaryNumber = number);
        _selectRoute(route);
        return;
      }
    }

    // The GTFS bundle knows this route but the legacy Firestore/seed list does
    // not. Still acknowledge the tap: highlight the row and clear the detail
    // card so the sheet never looks unresponsive.
    StageRouteSummary? summary;
    for (final s in _routeSummaries) {
      if (s.routeNumber == number) {
        summary = s;
        break;
      }
    }
    setState(() {
      _selectedSummaryNumber = number;
      _selectedRoute = null;
      _predictionResult = null;
      _isLoadingPrediction = false;
    });
    if (summary != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Route ${summary.routeNumber} heads to ${summary.headsign}.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildLegacyChips() {
    if (_isLoadingRoutes) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_routes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('No routes available for this stage'),
        ),
      );
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _routes.length,
        itemBuilder: (context, index) {
          final route = _routes[index];
          final isSelected = _selectedRoute?.id == route.id;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                route.number,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : NaviColors.textPrimary(
                          Theme.of(context).brightness == Brightness.dark),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => _selectRoute(route),
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? NaviColors.dividerDark
                  : Colors.grey[100],
              selectedColor: AppConstants.nairobiGreen,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaitTimeCard() {
    if (_isLoadingPrediction || _isLoadingSummaries) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Plain commuter language, never statistics. If the prediction is only a
    // synthetic default (no real reports yet), show the GTFS headway
    // frequency instead — or the honest "not recorded yet" when the bundle
    // has no headway data for this stage's time band.
    final prediction = _predictionResult;
    final hasRealReports = prediction != null &&
        ((prediction['reportCount'] as int?) ?? 0) > 0;
    final rawData = prediction?['data'];
    final lower = rawData is Map ? (rawData['lower'] as num?)?.toDouble() : null;
    final upper = rawData is Map ? (rawData['upper'] as num?)?.toDouble() : null;

    final String message;
    if (hasRealReports && lower != null && upper != null) {
      message =
          'Matatus arrive every ${lower.round()}–${upper.round()} min';
    } else {
      message = _frequencyText;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NaviColors.surface(
            Theme.of(context).brightness == Brightness.dark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
            color: NaviColors.dividerC(
                Theme.of(context).brightness == Brightness.dark)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 20,
            color: AppConstants.nairobiGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: NaviType.body.copyWith(
                color: NaviColors.textSecondary(
                    Theme.of(context).brightness == Brightness.dark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Navigate button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _handleNavigate, // Use the new handler
              icon: const Icon(Icons.directions),
              label: const Text('Navigate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.nairobiGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Report Wait button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _navigateToSubmit,
              icon: const Icon(Icons.timer),
              label: const Text('Report Wait'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.nairobiGreen,
                side: const BorderSide(color: AppConstants.nairobiGreen),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    if (_selectedRoute == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NaviColors.surface(
            Theme.of(context).brightness == Brightness.dark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: NaviColors.dividerC(
                Theme.of(context).brightness == Brightness.dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppConstants.nairobiGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedRoute!.number,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.nairobiGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedRoute!.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: NaviColors.textPrimary(
                        Theme.of(context).brightness == Brightness.dark),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Sacco info
          Row(
            children: [
              Icon(Icons.business,
                  size: 14,
                  color: NaviColors.textSecondary(
                      Theme.of(context).brightness == Brightness.dark)),
              const SizedBox(width: 4),
              Text(
                _selectedRoute!.sacco,
                style: TextStyle(
                  fontSize: 13,
                  color: NaviColors.textPrimary(
                      Theme.of(context).brightness == Brightness.dark),
                ),
              ),
            ],
          ),
          
          if (_selectedRoute!.description != null) ...[
            const SizedBox(height: 8),
            Text(
              _selectedRoute!.description!,
              style: TextStyle(
                fontSize: 13,
                color: NaviColors.textSecondary(
                    Theme.of(context).brightness == Brightness.dark),
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Major stops
          Text(
            'Major Stops:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: NaviColors.textSecondary(
                  Theme.of(context).brightness == Brightness.dark),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _selectedRoute!.majorStops.map((stop) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: NaviColors.surface(
                      Theme.of(context).brightness == Brightness.dark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: NaviColors.dividerC(
                          Theme.of(context).brightness == Brightness.dark)),
                ),
                child: Text(
                  stop,
                  style: TextStyle(
                    fontSize: 11,
                    color: NaviColors.textPrimary(
                        Theme.of(context).brightness == Brightness.dark),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: NaviColors.surface(
                Theme.of(context).brightness == Brightness.dark),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 16),
                    _buildRouteList(),
                    _buildWaitTimeCard(),
                    _buildRouteInfo(),
                    _buildActionButtons(),
                    
                    // Extra padding at bottom
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}