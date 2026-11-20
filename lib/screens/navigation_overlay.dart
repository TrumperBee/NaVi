import 'package:flutter/material.dart';

import '../models/active_journey.dart';
import '../models/transport_models.dart';
import '../widgets/active_nav/active_nav_data.dart';
import '../widgets/active_nav/active_nav_panel.dart';
import '../widgets/active_nav/active_nav_theme.dart';
import '../widgets/active_nav/nav_banner.dart';
import '../widgets/active_nav/nav_map_controls.dart';
import '../widgets/pre_trip_card.dart' show PreTripExtras;

/// The Active Navigation screen — the map-first layout shown after
/// "Start Journey".
///
/// Structure (all presentation; the journey engine, GPS, polyline trimming,
/// proximity alerts and voice guidance stay where they were):
/// * the map fills the screen behind everything,
/// * a near-black instruction banner floats under the status bar, with the
///   amber proximity strip docked directly beneath it,
/// * voice / compass / zoom controls float on the right edge just above the
///   panel,
/// * a draggable white panel carries the summary, the journey timeline and the
///   fixed End Journey action.
///
/// The panel opens at ~42% of the screen (raised on short screens so the
/// current step plus the next two are never clipped) and can be dragged to 80%.
class NavigationOverlay extends StatefulWidget {
  /// The map widget for the screen. The owner creates it with the journey
  /// route already rendered so a widget-instance swap never blanks the route.
  final Widget map;

  /// The live journey driving every number on this screen.
  final ActiveJourney journey;

  /// Stages for resolving boarding/alighting stage names.
  final List<StageModel> stages;

  /// Derived extras (stop counts and stop names) for the ride rows.
  final PreTripExtras? extras;

  /// Amber proximity message shown under the instruction banner; null hides it.
  final String? proximityMessage;

  /// Called when the user dismisses the amber strip early.
  final VoidCallback? onDismissProximity;

  final bool voiceGuidanceEnabled;
  final ValueChanged<bool> onToggleVoiceGuidance;
  final VoidCallback onEndTrip;

  /// Map camera hooks. Optional so the screen still renders (and tests) without
  /// a Mapbox instance; the owner wires them to the live map.
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onResetBearing;

  const NavigationOverlay({
    super.key,
    required this.map,
    required this.journey,
    this.stages = const [],
    this.extras,
    this.proximityMessage,
    this.onDismissProximity,
    required this.voiceGuidanceEnabled,
    required this.onToggleVoiceGuidance,
    required this.onEndTrip,
    this.onZoomIn,
    this.onZoomOut,
    this.onResetBearing,
  });

  /// The sheet's minimum height (a sliver above the handle + summary).
  static const double minExtent = 0.30;

  /// The sheet's maximum height, leaving the banner visible.
  static const double maxExtent = 0.80;

  /// Content the collapsed sheet actually renders: handle + summary + three
  /// timeline rows + End Journey. The fare/approximate rows and the system
  /// bottom inset are added by the caller when present.
  static const double collapsedContentPx = 296;
  static const double fareRowPx = 40;
  static const double approximateNotePx = 19;

  /// Opens exactly tall enough to show summary → current + next two → fare →
  /// End Journey. Taller phones therefore give the map more room instead of
  /// leaving an empty scroll viewport above the button.
  static double initialExtentFor(
    Size size, {
    double bottomInset = 0,
    bool hasFare = false,
    bool isApproximate = false,
  }) {
    if (size.height <= 0) return 0.40;
    final content = collapsedContentPx +
        bottomInset +
        (hasFare ? fareRowPx : 0) +
        (isApproximate ? approximateNotePx : 0);
    return (content / size.height).clamp(0.28, 0.62).toDouble();
  }

  /// Above this extent the panel shows every step (plus the stop rows).
  static const double expandedThreshold = 0.60;

  @override
  State<NavigationOverlay> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay> {
  final DraggableScrollableController _sheet = DraggableScrollableController();
  double? _extent;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  bool _handleExtent(double next) {
    final current = _extent;
    if (current != null && (current - next).abs() < 0.002) return false;
    final wasExpanded = _isExpanded(current);
    final nowExpanded = _isExpanded(next);
    setState(() => _extent = next);
    return wasExpanded != nowExpanded;
  }

  static bool _isExpanded(double? extent) =>
      (extent ?? 0.42) >= NavigationOverlay.expandedThreshold;

  @override
  Widget build(BuildContext context) {
    final data = ActiveNavData(
      journey: widget.journey,
      stages: widget.stages,
      extras: widget.extras,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final initial = NavigationOverlay.initialExtentFor(
          size,
          bottomInset: bottomInset,
          hasFare: data.hasFare,
          isApproximate: data.isApproximate,
        );
        final extent = (_extent ?? initial)
            .clamp(NavigationOverlay.minExtent, NavigationOverlay.maxExtent)
            .toDouble();
        final expanded = _isExpanded(extent);

        // The rail must sit above the panel and below the banner. When the
        // sheet is dragged far enough that both no longer fit on the map, the
        // controls step aside rather than colliding with the instruction card.
        final bannerBottom =
            MediaQuery.paddingOf(context).top + 8 + ActiveNavTheme.bannerHeight;

        return Stack(
          fit: StackFit.expand,
          children: [
            // --- MAP: fills the screen; the panel overlaps its lower part.
            Positioned.fill(child: widget.map),

            // --- INSTRUCTION + PROXIMITY BANNERS.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NavInstructionBanner(content: data.banner),
                      if (widget.proximityMessage != null) ...[
                        const SizedBox(height: 8),
                        NavProximityBanner(
                          message: widget.proximityMessage!,
                          onDismiss: widget.onDismissProximity,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // --- MAP CONTROLS: 16dp from the edge, above the panel.
            if (size.height * (1 - extent) >=
                bannerBottom + 16 + NavMapControls.railHeight)
              Positioned(
                right: 16,
                bottom: size.height * extent + 16,
                child: NavMapControls(
                  voiceEnabled: widget.voiceGuidanceEnabled,
                  onToggleVoice: () => widget
                      .onToggleVoiceGuidance(!widget.voiceGuidanceEnabled),
                  onZoomIn: widget.onZoomIn,
                  onZoomOut: widget.onZoomOut,
                  onResetBearing: widget.onResetBearing,
                ),
              ),

            // --- BOTTOM PANEL.
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                _handleExtent(notification.extent);
                return false;
              },
              child: DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: initial,
                minChildSize: NavigationOverlay.minExtent,
                maxChildSize: NavigationOverlay.maxExtent,
                snap: true,
                snapSizes: [initial, NavigationOverlay.maxExtent],
                builder: (context, scrollController) => ActiveNavPanel(
                  data: data,
                  scrollController: scrollController,
                  expanded: expanded,
                  onEndTrip: widget.onEndTrip,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
