import 'package:flutter/material.dart';

import '../design/navi_spacing.dart';
import '../design/navi_typography.dart';
import '../models/active_journey.dart';
import '../models/route_segment.dart';
import '../widgets/journey_info_panel.dart';
import '../widgets/route_badge.dart';

/// The Active Navigation screen — replaces the full-screen-map + sparse
/// floating overlays with a two-zone layout (Uber driver-navigation style):
/// the map occupies the top ~55% and a distinct info panel the bottom ~45%.
///
/// The map plus its floating [ManeuverBanner] live in the top zone; real
/// journey content (remaining time/distance, current step, upcoming steps,
/// running fare, voice + End Trip controls) lives in [JourneyInfoPanel].
class NavigationOverlay extends StatelessWidget {
  /// The map widget for the top zone. The owner creates it with the journey
  /// route already rendered so a widget-instance swap never blanks the route.
  final Widget map;

  /// The live journey driving every number in the overlay.
  final ActiveJourney journey;

  final bool voiceGuidanceEnabled;
  final ValueChanged<bool> onToggleVoiceGuidance;
  final VoidCallback onEndTrip;

  const NavigationOverlay({
    super.key,
    required this.map,
    required this.journey,
    required this.voiceGuidanceEnabled,
    required this.onToggleVoiceGuidance,
    required this.onEndTrip,
  });

  /// Responsive map/info flex split (map flex, info flex), scaled to the
  /// available screen height:
  ///   - phones < 600 dp of height   -> (52, 48)
  ///   - tablets > 900 dp            -> (57, 43)
  ///   - everything in between       -> (55, 45)
  ///
  /// The info zone is never allowed to shrink below ~43% so the journey
  /// content stays legible on small screens, and never above ~48% so the map
  /// always keeps the visible majority.
  static (int, int) mapZoneFlexFor(double height) {
    if (height < 600) return (52, 48);
    if (height > 900) return (57, 43);
    return (55, 45);
  }

  @override
  Widget build(BuildContext context) {
    final (mapFlex, infoFlex) =
        mapZoneFlexFor(MediaQuery.of(context).size.height);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- MAP ZONE (top) ---
        Expanded(
          flex: mapFlex,
          child: Stack(
            children: [
              Positioned.fill(child: map),
              // Compact floating maneuver banner, safe-area aware.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        NaviSpacing.lg, NaviSpacing.sm, NaviSpacing.lg, 0),
                    child: ManeuverBanner(
                      currentSegment: journey.currentSegment,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // --- INFO ZONE (bottom) ---
        Expanded(
          flex: infoFlex,
          child: JourneyInfoPanel(
            journey: journey,
            voiceGuidanceEnabled: voiceGuidanceEnabled,
            onToggleVoiceGuidance: onToggleVoiceGuidance,
            onEndTrip: onEndTrip,
          ),
        ),
      ],
    );
  }
}

/// Compact always-visible banner floating over the top map zone: mode icon +
/// phase label + the current step in plain language. The single line it shows
/// repeats the current step text from [JourneyInfoPanel] so the driver's eye
/// can stay on the map.
class ManeuverBanner extends StatelessWidget {
  /// The active segment; null once the journey is complete.
  final RouteSegment? currentSegment;

  const ManeuverBanner({super.key, required this.currentSegment});

  static const Color _kHudEmerald = Color(0xFF064E3B);

  @override
  Widget build(BuildContext context) {
    final segment = currentSegment;

    return Container(
      decoration: BoxDecoration(
        color: _kHudEmerald,
        borderRadius: BorderRadius.circular(NaviRadius.card),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: NaviSpacing.md, vertical: NaviSpacing.sm),
      child: Row(
        children: [
          if (segment == null)
            const Icon(Icons.check_circle, color: Colors.white, size: 26)
          else if (segment.mode == SegmentMode.walk)
            const Icon(Icons.directions_walk, color: Colors.white, size: 26)
          else
            RouteBadge(routeNumber: segment.routeNumber ?? '—'),
          const SizedBox(width: NaviSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_phaseLabel(segment),
                    style: NaviType.caption.copyWith(
                        color: Colors.white70,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(
                  segment?.label ?? 'Journey Complete',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NaviType.cardTitle.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _phaseLabel(RouteSegment? segment) {
    if (segment == null) return 'ARRIVED';
    switch (segment.mode) {
      case SegmentMode.walk:
        return 'WALKING';
      case SegmentMode.matatu:
        return 'ON ROUTE ${segment.routeNumber ?? ''}';
    }
  }
}