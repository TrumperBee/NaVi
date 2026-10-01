import 'package:flutter/material.dart';

/// The one deliberate animated moment on the Active Navigation screen: the
/// current-step card slide + fade that plays when the journey advances to the
/// next segment (walk → matatu → walk).
const Duration kManeuverTransitionDuration = Duration(milliseconds: 300);

/// Wraps a step's content in the maneuver transition. The outgoing card
/// slides/fades out while the incoming one slides/fades in — a single
/// [AnimatedSwitcher] keyed by [stepIndex].
///
/// Honors the OS reduced-motion setting: when
/// `MediaQuery.of(context).disableAnimations` is true the switch is
/// instantaneous and content still updates.
class ManeuverTransition extends StatelessWidget {
  /// The changing key — when it differs from the previous build the outer
  /// [AnimatedSwitcher] runs the slide + fade.
  final int stepIndex;

  final Widget child;

  const ManeuverTransition({
    super.key,
    required this.stepIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedSwitcher(
      duration:
          reduceMotion ? Duration.zero : kManeuverTransitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: reduceMotion
          ? (child, animation) => child
          : (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.10, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              ),
      child: KeyedSubtree(
        key: ValueKey<int>(stepIndex),
        child: child,
      ),
    );
  }
}

/// Tween-animates a numeric metric (remaining minutes, remaining distance)
/// toward new values as the journey progresses. The numeral eases over
/// [kManeuverTransitionDuration] instead of snapping.
///
/// Honors the OS reduced-motion setting by resolving straight to the target
/// value when animations are disabled.
class TweenMetric extends StatelessWidget {
  /// The target value. On each rebuild the widget animates from the last
  /// rendered value toward this one.
  final double value;

  /// Builds the metric from the interpolated value.
  final Widget Function(BuildContext context, double value) builder;

  const TweenMetric({
    super.key,
    required this.value,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration:
          reduceMotion ? Duration.zero : kManeuverTransitionDuration,
      curve: Curves.easeOutCubic,
      builder: (context, current, child) => builder(context, current),
    );
  }
}