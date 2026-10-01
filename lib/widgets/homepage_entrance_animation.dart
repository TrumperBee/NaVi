import 'package:flutter/material.dart';

/// The homepage's one orchestrated entrance sequence.
///
/// A single [AnimationController] drives three staggered regions via
/// [Interval] curves, so the cold-launch load reads as one choreographed
/// moment rather than three independent pop-ins:
///
///  1. Map fades in first           0–200ms
///  2. Search bar + Quick Go slide down / fade     100–350ms
///  3. Bottom sheet slides up from below           250–550ms
///
/// Total ≈ 550ms of an explicit 600ms budget, all under the [totalDuration].
///
/// Reduced motion: when `MediaQuery.disableAnimations` is true the sequence is
/// skipped entirely and the final state is rendered on the first frame.
///
/// The [builder] receives three parented [Animation]s and applies whatever
/// transforms it needs (map fade, top-bar slide, sheet slide). The wrapper
/// plays once per [State] creation, so it never replays on screen revisits.
class HomepageEntranceAnimation extends StatefulWidget {
  const HomepageEntranceAnimation({super.key, required this.builder});

  final Widget Function(
    BuildContext context,
    Animation<double> map,
    Animation<double> topBar,
    Animation<double> bottomSheet,
  ) builder;

  /// 600ms covers the whole sequence with a little headroom.
  static const Duration totalDuration = Duration(milliseconds: 600);

  @override
  State<HomepageEntranceAnimation> createState() =>
      _HomepageEntranceAnimationState();
}

class _HomepageEntranceAnimationState extends State<HomepageEntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _map;
  late final Animation<double> _topBar;
  late final Animation<double> _bottomSheet;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: HomepageEntranceAnimation.totalDuration,
    );
    // Fraction-of-600ms boundaries: map 0–200, top 100–350, sheet 250–550.
    _map = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.34, curve: Curves.easeOut),
    );
    _topBar = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.17, 0.58, curve: Curves.easeOutCubic),
    );
    _bottomSheet = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.92, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      // Reduced motion: jump straight to the final, fully-settled state.
      _controller.value = 1.0;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _map, _topBar, _bottomSheet);
  }
}