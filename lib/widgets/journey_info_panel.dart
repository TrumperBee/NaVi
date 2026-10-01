import 'package:flutter/material.dart';

import '../design/navi_colors.dart';
import '../design/navi_spacing.dart';
import '../design/navi_typography.dart';
import '../models/active_journey.dart';
import '../models/route_segment.dart';
import '../utils/distance_formatter.dart';
import 'maneuver_transition.dart';
import 'route_badge.dart';

/// The bottom info zone of the Active Navigation screen.
///
/// Real journey content instead of a blank white card: remaining time + distance
/// as large legible numerals, the current step in plain language (animated via
/// [ManeuverTransition] on every segment change), a greyed preview of the next
/// steps, the running fare once boarding begins, and a fixed bottom action row
/// (voice toggle + red End Trip).
class JourneyInfoPanel extends StatelessWidget {
  /// The live journey. All numbers are derived from this single object so the
  /// panel can never disagree with the map or the maneuver banner.
  final ActiveJourney journey;

  final bool voiceGuidanceEnabled;
  final ValueChanged<bool> onToggleVoiceGuidance;
  final VoidCallback onEndTrip;

  const JourneyInfoPanel({
    super.key,
    required this.journey,
    required this.voiceGuidanceEnabled,
    required this.onToggleVoiceGuidance,
    required this.onEndTrip,
  });

  static const Color _kEndTripRed = Color(0xFFC62828);

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
                      _buildFareTotal(context, isDark),
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
              Text('FINAL TIME',
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
      title: _currentStepText(segment),
      subtitle: _stepContextLine(segment),
      trailing: segment.mode == SegmentMode.matatu && segment.routeNumber != null
          ? RouteBadge(routeNumber: segment.routeNumber!)
          : null,
      isDark: isDark,
    );
  }

  String _currentStepText(RouteSegment segment) {
    switch (segment.mode) {
      case SegmentMode.walk:
        return segment.label.replaceFirst('Walk to ', 'Walking to ');
      case SegmentMode.matatu:
        return segment.label.replaceFirst('Ride ', 'On ');
    }
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
            text: segment.label,
            routeNumber: segment.routeNumber,
            isDark: isDark,
          ),
          const SizedBox(height: NaviSpacing.xs),
        ],
      ],
    );
  }

  // ============== RUNNING FARE TOTAL ==============

  Widget _buildFareTotal(BuildContext context, bool isDark) {
    // Fare accrues from the moment the user boards. Walking segments always
    // contribute 0, so before boarding begins the total is KSh 0 and the row is
    // omitted entirely.
    final runningFare = journey.segments
        .take(journey.currentSegmentIndex + 1)
        .fold<int>(0, (sum, s) => sum + (s.fareEstimate?.amountKsh ?? 0));
    if (runningFare <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: NaviSpacing.xs),
      padding: NaviInsets.badge,
      decoration: BoxDecoration(
        color: NaviColors.canvas(isDark),
        borderRadius: BorderRadius.circular(NaviRadius.card),
        border: Border.all(color: NaviColors.dividerC(isDark)),
      ),
      child: Row(
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
    );
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
              onPressed: onEndTrip,
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