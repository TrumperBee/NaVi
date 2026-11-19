import 'package:flutter/material.dart';

import '../design/navi_colors.dart';
import '../design/navi_spacing.dart';
import '../design/navi_typography.dart';
import '../models/active_journey.dart';
import '../models/route_segment.dart';
import '../models/transport_models.dart';
import '../utils/distance_formatter.dart';
import 'maneuver_transition.dart';
import 'pre_trip_card.dart';
import 'route_badge.dart';

/// The bottom info zone of the Active Navigation screen.
///
/// Real journey content instead of a blank white card: remaining time + distance
/// as large legible numerals, the current step in plain language (animated via
/// [ManeuverTransition] on every segment change), a greyed preview of the next
/// steps, the running fare + the stage to get off at while riding, and a fixed
/// bottom action row (voice toggle + red End Trip behind a confirm dialog).
class JourneyInfoPanel extends StatelessWidget {
  /// The live journey. All numbers are derived from this single object so the
  /// panel can never disagree with the map or the maneuver banner.
  final ActiveJourney journey;

  /// Stages for resolving the alighting stage's name from its id.
  final List<StageModel> stages;

  /// Derived extras (stop counts) for the "Get off at …" line; optional —
  /// the line degrades gracefully when absent.
  final PreTripExtras? extras;

  final bool voiceGuidanceEnabled;
  final ValueChanged<bool> onToggleVoiceGuidance;
  final VoidCallback onEndTrip;

  const JourneyInfoPanel({
    super.key,
    required this.journey,
    this.stages = const [],
    this.extras,
    required this.voiceGuidanceEnabled,
    required this.onToggleVoiceGuidance,
    required this.onEndTrip,
  });

  static const Color _kEndTripRed = Color(0xFFC62828);

  /// True when [text] is a bare `lat, lng` pair — never render those raw
  /// coordinates as user-facing copy on the navigation screen.
  static bool looksLikeCoordinates(String text) {
    return RegExp(r'^[+-]?\d{1,3}\.\d+\s*,\s*[+-]?\d{1,3}\.\d+$')
        .hasMatch(text.trim());
  }

  /// Plain-language wording for a segment's current step:
  /// walk legs keep their `Walk to …` label (with a coordinate-safe fallback
  /// to "your destination"), ride legs read `On Route 58 to …`. Shared by the
  /// panel's step card and the maneuver banner so they can never disagree.
  static String plainStepText(RouteSegment segment) {
    if (segment.mode == SegmentMode.matatu) {
      final text = segment.label.replaceFirst('Ride ', 'On ');
      const marker = ' to ';
      final index = text.lastIndexOf(marker);
      if (index >= 0) {
        final tail = text.substring(index + marker.length).trim();
        if (looksLikeCoordinates(tail)) return text.substring(0, index);
      }
      return text;
    }
    return _plainWalkText(segment.label);
  }

  /// Label wording for the muted "up next" preview rows: keeps the builder's
  /// original wording (e.g. `Ride Route 58 to …`) but applies the same
  /// coordinate guards, so a raw `lat, lng` never reaches the screen.
  static String plainSegmentLabel(RouteSegment segment) {
    if (segment.mode == SegmentMode.walk) {
      return _plainWalkText(segment.label);
    }
    final label = segment.label;
    const marker = ' to ';
    final index = label.lastIndexOf(marker);
    if (index >= 0) {
      final tail = label.substring(index + marker.length).trim();
      if (looksLikeCoordinates(tail)) return label.substring(0, index);
    }
    return looksLikeCoordinates(label) ? 'Destination' : label;
  }

  static String _plainWalkText(String label) {
    const prefix = 'Walk to ';
    if (label.startsWith(prefix)) {
      final target = label.substring(prefix.length).trim();
      if (target.isEmpty || looksLikeCoordinates(target)) {
        return 'Walk to your destination';
      }
    } else if (looksLikeCoordinates(label)) {
      return 'Walk to your destination';
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 16,
      color: NaviColors.surface(isDark),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              NaviSpacing.lg, NaviSpacing.md, NaviSpacing.lg, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isDark),
              const SizedBox(height: NaviSpacing.sm),
              ManeuverTransition(
                stepIndex: journey.currentSegmentIndex,
                child: _buildCurrentStepCard(context, isDark),
              ),
              const SizedBox(height: NaviSpacing.sm),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildUpcomingSteps(context, isDark),
                      _buildFareAndStop(context, isDark),
                    ],
                  ),
                ),
              ),
              _buildActionRow(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ============== HEADER: remaining time + distance ==============

  Widget _buildHeader(BuildContext context, bool isDark) {
    final remaining = journey.remainingDuration;
    final remainingMin = remaining.inSeconds < 60
        ? (journey.isComplete ? 0 : 1)
        : remaining.inMinutes;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('REMAINING',
                  style: NaviType.caption.copyWith(
                      color: NaviColors.textSecondary(isDark),
                      letterSpacing: 0.4)),
              const SizedBox(height: NaviSpacing.xs),
              TweenMetric(
                value: remainingMin.toDouble(),
                builder: (context, v) => Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${v.round()}',
                        style: NaviType.title.copyWith(
                          color: NaviColors.textPrimary(isDark),
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: '  min',
                        style: NaviType.caption.copyWith(
                            color: NaviColors.textSecondary(isDark)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DISTANCE',
                  style: NaviType.caption.copyWith(
                      color: NaviColors.textSecondary(isDark),
                      letterSpacing: 0.4)),
              const SizedBox(height: NaviSpacing.xs),
              TweenMetric(
                value: journey.remainingDistanceMeters,
                builder: (context, v) => Text(
                  DistanceFormatter.format(v),
                  style: NaviType.title.copyWith(
                    color: NaviColors.textPrimary(isDark),
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============== CURRENT STEP CARD ==============

  Widget _buildCurrentStepCard(BuildContext context, bool isDark) {
    final segment = journey.currentSegment;
    if (segment == null || journey.isComplete) {
      return _StepCard(
        leading: const Icon(Icons.check_circle,
            size: 32, color: NaviColors.transitGreen),
        title: 'Arrived at your destination',
        subtitle: 'Journey complete',
        isDark: isDark,
      );
    }

    return _StepCard(
      leading: segment.mode == SegmentMode.walk
          ? const Icon(Icons.directions_walk,
              size: 32, color: NaviColors.transitGreen)
          : Icon(
              Icons.directions_bus,
              size: 32,
              color: _modeIconColor(segment, isDark),
            ),
      title: plainStepText(segment),
      subtitle: _stepContextLine(segment),
      trailing: segment.mode == SegmentMode.matatu && segment.routeNumber != null
          ? RouteBadge(routeNumber: segment.routeNumber!)
          : null,
      isDark: isDark,
    );
  }

  String _stepContextLine(RouteSegment segment) {
    switch (segment.mode) {
      case SegmentMode.walk:
        return 'Continue on foot';
      case SegmentMode.matatu:
        return 'Matatu · public service vehicle';
    }
  }

  Color _modeIconColor(RouteSegment segment, bool isDark) {
    return segment.mode == SegmentMode.matatu
        ? (isDark ? NaviColors.canvasDark : NaviColors.ink)
        : NaviColors.transitGreen;
  }

  // ============== UPCOMING STEPS PREVIEW ==============

  Widget _buildUpcomingSteps(BuildContext context, bool isDark) {
    final upcoming = journey.upcomingSegments.take(2).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('UP NEXT',
            style: NaviType.caption.copyWith(
                color: NaviColors.textSecondary(isDark), letterSpacing: 0.4)),
        const SizedBox(height: NaviSpacing.xs),
        for (final segment in upcoming) ...[
          _UpcomingStepRow(
            mode: segment.mode,
            text: plainSegmentLabel(segment),
            routeNumber: segment.routeNumber,
            isDark: isDark,
          ),
          const SizedBox(height: NaviSpacing.xs),
        ],
      ],
    );
  }

  // ============== RUNNING FARE + GET-OFF STAGE ==============

  /// Fare so far while walking/riding, plus — while on the matatu — the stage
  /// to get off at with its stop count ("Get off at Jerusalem, 5 stops").
  /// Hidden entirely before any fare accrues and no ride is in progress.
  Widget _buildFareAndStop(BuildContext context, bool isDark) {
    // Fare accrues from the moment the user boards. Walking segments always
    // contribute 0, so before boarding begins the total is KSh 0.
    final runningFare = journey.segments
        .take(journey.currentSegmentIndex + 1)
        .fold<int>(0, (sum, s) => sum + (s.fareEstimate?.amountKsh ?? 0));
    final getOff = _getOffLine();
    if (runningFare <= 0 && getOff == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: NaviSpacing.xs),
      padding: NaviInsets.badge,
      decoration: BoxDecoration(
        color: NaviColors.canvas(isDark),
        borderRadius: BorderRadius.circular(NaviRadius.card),
        border: Border.all(color: NaviColors.dividerC(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (runningFare > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('FARE SO FAR',
                    style: NaviType.caption.copyWith(
                        color: NaviColors.textSecondary(isDark),
                        letterSpacing: 0.4)),
                TweenMetric(
                  value: runningFare.toDouble(),
                  builder: (context, v) => Text(
                    'KSh ${v.round()}',
                    style: NaviType.title.copyWith(
                      color: NaviColors.textPrimary(isDark),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          if (runningFare > 0 && getOff != null)
            Padding(
              padding: const EdgeInsets.only(top: NaviSpacing.xs),
              child: Container(height: 1, color: NaviColors.dividerC(isDark)),
            ),
          if (getOff != null)
            Padding(
              padding: runningFare > 0
                  ? const EdgeInsets.only(top: NaviSpacing.xs)
                  : EdgeInsets.zero,
              child: Row(
                children: [
                  Icon(Icons.logout, size: 16, color: NaviColors.textSecondary(isDark)),
                  const SizedBox(width: NaviSpacing.sm),
                  Expanded(
                    child: Text(
                      getOff,
                      style: NaviType.body.copyWith(
                        color: NaviColors.textPrimary(isDark),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// "Get off at Jerusalem, 5 stops" while riding; null otherwise. The stage
  /// name resolves from its id (falling back to the segment label's `to …`
  /// tail, never a raw coordinate); the stop count comes from [extras].
  String? _getOffLine() {
    final segment = journey.currentSegment;
    if (segment == null ||
        journey.isComplete ||
        segment.mode != SegmentMode.matatu) {
      return null;
    }
    final stops = extras?.stopCounts[journey.currentSegmentIndex];
    final stopText = stops == null
        ? null
        : (stops == 1 ? '1 stop' : '$stops stops');
    final name = _alightStageName(segment);
    if (name == null) {
      return stopText == null ? null : 'Get off in $stopText';
    }
    return stopText == null ? 'Get off at $name' : 'Get off at $name, $stopText';
  }

  String? _alightStageName(RouteSegment segment) {
    final id = segment.toStageId;
    if (id != null && id.isNotEmpty) {
      for (final stage in stages) {
        if (stage.id == id) return stage.name;
      }
    }
    const marker = ' to ';
    final label = segment.label;
    final index = label.lastIndexOf(marker);
    if (index >= 0) {
      final target = label.substring(index + marker.length).trim();
      if (target.isNotEmpty && !looksLikeCoordinates(target)) return target;
    }
    return null;
  }

  // ============== BOTTOM ACTION ROW (fixed at panel bottom) ==============

  Widget _buildActionRow(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NaviSpacing.md),
      child: Row(
        children: [
          _VoiceToggle(
            enabled: voiceGuidanceEnabled,
            isDark: isDark,
            onTap: () => onToggleVoiceGuidance(!voiceGuidanceEnabled),
          ),
          const SizedBox(width: NaviSpacing.md),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _confirmEndTrip(context),
              style: FilledButton.styleFrom(
                backgroundColor: _kEndTripRed,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
              label: const Text('End Trip',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  /// Red End Trip is destructive mid-journey, so it always passes through a
  /// confirm dialog before [onEndTrip] fires.
  Future<void> _confirmEndTrip(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End this trip?'),
        content: const Text(
            'You still have a way to go. End the trip and stop navigation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep riding'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _kEndTripRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );
    if (confirmed == true) onEndTrip();
  }
}

/// Shared card shell for the current step / arrived state.
class _StepCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool isDark;

  const _StepCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NaviSpacing.md),
      decoration: BoxDecoration(
        color: NaviColors.canvas(isDark),
        borderRadius: BorderRadius.circular(NaviRadius.card),
        border: Border.all(color: NaviColors.dividerC(isDark)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NaviColors.surface(isDark),
              borderRadius: BorderRadius.circular(NaviRadius.card),
            ),
            child: leading,
          ),
          const SizedBox(width: NaviSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: NaviType.cardTitle.copyWith(
                    color: NaviColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: NaviType.caption.copyWith(
                        color: NaviColors.textSecondary(isDark))),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: NaviSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _UpcomingStepRow extends StatelessWidget {
  final SegmentMode mode;
  final String text;
  final String? routeNumber;
  final bool isDark;

  const _UpcomingStepRow({
    required this.mode,
    required this.text,
    this.routeNumber,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final muted = NaviColors.textSecondary(isDark);
    return Row(
      children: [
        Icon(
          mode == SegmentMode.walk
              ? Icons.directions_walk
              : Icons.directions_bus,
          size: 18,
          color: muted,
        ),
        const SizedBox(width: NaviSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NaviType.body.copyWith(color: muted),
          ),
        ),
        if (mode == SegmentMode.matatu && routeNumber != null) ...[
          const SizedBox(width: NaviSpacing.sm),
          Text(routeNumber!,
              style: NaviType.caption.copyWith(
                  color: muted, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }
}

class _VoiceToggle extends StatelessWidget {
  final bool enabled;
  final bool isDark;
  final VoidCallback onTap;

  const _VoiceToggle({
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = enabled ? NaviColors.transitGreen : NaviColors.textSecondary(isDark);
    return Material(
      color: NaviColors.canvas(isDark),
      borderRadius: BorderRadius.circular(NaviRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NaviRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: NaviSpacing.md, vertical: NaviSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                enabled ? Icons.volume_up : Icons.volume_off,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: NaviSpacing.xs),
              Text(
                enabled ? 'On' : 'Off',
                style: NaviType.caption.copyWith(
                    color: accent, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}