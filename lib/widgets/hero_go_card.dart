import 'package:flutter/material.dart';

import '../design/navi_colors.dart';
import '../design/navi_spacing.dart';
import '../design/navi_typography.dart';
import 'route_badge.dart';

/// The promoted nearest-stage hero card.
///
/// The only card allowed a dark ink background so it reads as clearly
/// promoted. The walk-time numeral is rendered in [NaviType.heroNumeral] —
/// the one deliberate typographic moment on the homepage — while everything
/// else stays quiet (muted white/grey).
class HeroGoCard extends StatelessWidget {
  final String stageName;
  final String distanceLabel;
  final String walkTimeLabel;
  final List<String> routeNumbers;
  final VoidCallback? onTap;

  /// Optional small eyebrow above the stage name (e.g. "Nearest stage") that
  /// puts the hero’s promoted-content claim into words on the homepage.
  final String? labelTitle;

  const HeroGoCard({
    super.key,
    required this.stageName,
    required this.distanceLabel,
    required this.walkTimeLabel,
    required this.routeNumbers,
    this.onTap,
    this.labelTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NaviColors.ink,
      borderRadius: BorderRadius.circular(NaviRadius.heroCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
child: Padding(
        padding: EdgeInsets.fromLTRB(
          NaviInsets.heroCard.left,
          NaviInsets.heroCard.top,
          NaviInsets.heroCard.right,
          // Extra bottom cushion keeps the shimmer bars clear of the
          // bottom-anchored status line ("Getting your location…").
          NaviInsets.heroCard.bottom + 34,
        ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (labelTitle != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.near_me,
                        size: 14, color: NaviColors.transitGreen),
                    const SizedBox(width: 4),
                    Text(
                      labelTitle!,
                      style: NaviType.caption.copyWith(
                        color: NaviColors.transitGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NaviSpacing.xs),
              ],
              // FittedBox guards against overflow/clipping when the user
              // runs the device at a large accessibility text scale.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  stageName,
                  style: NaviType.title.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: NaviSpacing.xs),
              Text(
                distanceLabel,
                style: NaviType.caption.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: NaviSpacing.lg),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _WalkTimeLabel(label: walkTimeLabel),
              ),
              const SizedBox(height: NaviSpacing.lg),
              RouteBadgeRow(routeNumbers: routeNumbers),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalkTimeLabel extends StatelessWidget {
  final String label;
  static final _leadingNumeral = RegExp(r'^\s*(\d+)');

  const _WalkTimeLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final match = _leadingNumeral.firstMatch(label);
    if (match == null) {
      return Text(
        label,
        style: NaviType.caption.copyWith(color: Colors.white70),
      );
    }

    final numeral = match.group(1)!;
    final rest = label.substring(match.end).trim();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          numeral,
          style: NaviType.heroNumeral.copyWith(color: Colors.white),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(width: NaviSpacing.sm),
          Text(
            rest,
            style: NaviType.caption.copyWith(color: Colors.white70),
          ),
        ],
      ],
    );
  }
}

/// Graceful stand-in for [HeroGoCard] when the user has not yet granted
/// location permission, so the homepage never renders a blank hero slot.
///
/// This is deliberately quiet — canvas, hairline border — because it stands in
/// for the hero card, which is otherwise the only bold element on the page.
class HeroGoCardPlaceholder extends StatelessWidget {
  final VoidCallback? onEnableLocation;

  const HeroGoCardPlaceholder({super.key, this.onEnableLocation});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: NaviInsets.card,
      decoration: BoxDecoration(
        color: NaviColors.canvas(isDark),
        borderRadius: BorderRadius.circular(NaviRadius.card),
        border: Border.all(color: NaviColors.dividerC(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.my_location, color: NaviColors.signalBlue, size: 22),
          const SizedBox(height: NaviSpacing.sm),
          Text(
            'Enable location to see your nearest stage',
            style: NaviType.body.copyWith(
              color: NaviColors.textPrimary(isDark),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: NaviSpacing.sm),
          Text(
            'Turn on GPS to promote the closest stage to the top.',
            style: NaviType.caption.copyWith(
              color: NaviColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: NaviSpacing.md),
          FilledButton.icon(
            onPressed: onEnableLocation,
            icon: const Icon(Icons.location_on_outlined, size: 18),
            label: const Text('Enable Location'),
            style: FilledButton.styleFrom(
              backgroundColor: NaviColors.transitGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
          ),
        ],
      ),
    );
  }
}

/// Informative stand-in for [HeroGoCard] when the user has a GPS fix but no
/// stage is within a reasonable range (e.g. outside the Nairobi metro).
///
/// Explains what happened rather than apologizing or being vague; not an error
/// tone. Quiet canvas + hairline border, matching the other hero stand-ins.
class HeroGoCardEmptyState extends StatelessWidget {
  const HeroGoCardEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: NaviInsets.card,
      decoration: BoxDecoration(
        color: NaviColors.canvas(isDark),
        borderRadius: BorderRadius.circular(NaviRadius.card),
        border: Border.all(color: NaviColors.dividerC(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.pin_drop_outlined,
            color: NaviColors.textSecondary(isDark),
            size: 22,
          ),
          const SizedBox(height: NaviSpacing.sm),
          Text(
            'No stages nearby yet',
            style: NaviType.body.copyWith(
              color: NaviColors.textPrimary(isDark),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: NaviSpacing.sm),
          Text(
            'NaVi currently covers Nairobi metro routes. A stage will appear '
            'here once one comes within range.',
            style: NaviType.caption.copyWith(
              color: NaviColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the nearest-stage lookup is waiting on, so the loading card can say
/// exactly what is happening instead of showing a silent spinner.
enum HeroGoLoadPhase {
  /// Waiting for a GPS fix from the platform location services.
  locating('Getting your location…'),

  /// GPS resolved; computing/awaiting the nearest-stage match.
  findingStages('Finding nearby stages…');

  final String label;
  const HeroGoLoadPhase(this.label);
}

/// Informative stand-in for [HeroGoCard] when no GPS fix has arrived within
/// the location-fix timeout (~8s).
///
/// Replaces the perpetual loading shimmer with a concrete, actionable message
/// ("Still finding your location — check your GPS signal") and a manual retry
/// button, so the homepage can never sit in an indefinite loading state.
class HeroGoCardLocationTimeout extends StatelessWidget {
  final VoidCallback? onRetry;

  const HeroGoCardLocationTimeout({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NaviColors.ink,
      borderRadius: BorderRadius.circular(NaviRadius.heroCard),
      child: Padding(
        padding: NaviInsets.heroCard,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.gps_off, color: Colors.white70, size: 22),
            const SizedBox(height: NaviSpacing.sm),
            Text(
              'Still finding your location',
              style: NaviType.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: NaviSpacing.xs),
            Text(
              'Check your GPS signal, then try again.',
              style: NaviType.caption.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: NaviSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: NaviColors.transitGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading stand-in for [HeroGoCard] while the GPS fix is still resolving.
///
/// Shows a skeleton shimmer on the ink hero background — not a generic spinner
/// and not a full-card blank. A status line beneath the skeleton names the
/// current wait phase ("Getting your location…" → "Finding nearby stages…") so
/// the user understands what is happening instead of seeing a frozen card. The
/// appropriate final-height is reserved by laying out an invisible real
/// [HeroGoCard] underneath, so swapping in the live card later does not cause
/// a layout jump.
class HeroGoCardLoading extends StatelessWidget {
  final String stageName;
  final String distanceLabel;
  final String walkTimeLabel;
  final List<String> routeNumbers;

  /// Which wait is currently happening; drives the visible status text.
  final HeroGoLoadPhase phase;

  const HeroGoCardLoading({
    super.key,
    this.stageName = 'Nearest stage',
    this.distanceLabel = 'Locating',
    this.walkTimeLabel = 'Locating',
    this.routeNumbers = const ['00', '00'],
    this.phase = HeroGoLoadPhase.locating,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: phase.label,
      child: ExcludeSemantics(
        child: Material(
          color: NaviColors.ink,
          borderRadius: BorderRadius.circular(NaviRadius.heroCard),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: HeroGoCard(
                    stageName: stageName,
                    distanceLabel: distanceLabel,
                    walkTimeLabel: walkTimeLabel,
                    routeNumbers: routeNumbers,
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _HeroSkeleton(),
              ),
              Positioned(
                left: NaviInsets.heroCard.left,
                right: NaviInsets.heroCard.right,
                bottom: NaviInsets.heroCard.bottom,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        phase.label,
                        style: NaviType.caption.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatefulWidget {
  const _HeroSkeleton();

  @override
  State<_HeroSkeleton> createState() => _HeroSkeletonState();
}

class _HeroSkeletonState extends State<_HeroSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final sweep = _controller.value;
        final base = Colors.white.withValues(alpha: 0.10);
        final sheen = Colors.white.withValues(alpha: 0.22);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final center = -0.6 + (2.0 * sweep);
            return LinearGradient(
              colors: [base, sheen, base],
              stops: [
                center.clamp(0.0, 1.0),
                (center + 0.25).clamp(0.0, 1.0),
                (center + 0.5).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Padding(
        padding: NaviInsets.heroCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _shimmerBar(widthFactor: 0.6, height: 18),
            const SizedBox(height: NaviSpacing.xs),
            _shimmerBar(widthFactor: 0.4, height: 12),
            const SizedBox(height: NaviSpacing.lg),
            _shimmerBar(widthFactor: 0.24, height: 34),
            const SizedBox(height: NaviSpacing.lg),
            const Row(
              children: [
                _ShimmerBadge(),
                SizedBox(width: NaviSpacing.badgeGap),
                _ShimmerBadge(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton line shaped like the hero card's text rows. The bar itself is
/// opaque; the [ShaderMask] in [_HeroSkeletonState] tints it with the sheen.
Widget _shimmerBar({required double widthFactor, required double height}) {
  return FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: widthFactor,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SizedBox(height: height),
    ),
  );
}

/// A skeleton shard shaped like a route badge.
class _ShimmerBadge extends StatelessWidget {
  const _ShimmerBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(NaviRadius.badge),
        ),
      ),
    );
  }
}