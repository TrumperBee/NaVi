import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';
import '../../design/navi_spacing.dart';
import '../../design/navi_typography.dart';
import '../../models/transport_models.dart';
import '../../services/stage_route_summary.dart';
import 'route_preview_data.dart';
import 'route_preview_theme.dart';

/// Everything below the drag handle of the Route Preview sheet.
///
/// The sheet is dumb on purpose: it renders the values in [data] and the
/// supplied stage routes, and reports taps upwards. All map concerns (line,
/// markers, camera) stay in the screen / Home.
class RoutePreviewSheet extends StatelessWidget {
  final RoutePreviewMode mode;
  final RoutePreviewData? data;
  final List<RoutePreviewAlternative> alternatives;
  final String destinationLabel;
  final String? stageName;
  final List<StageRouteSummary> stageRoutes;
  final bool loading;
  final bool error;
  final ScrollController scrollController;
  final VoidCallback onStartJourney;
  final VoidCallback onRetry;
  final ValueChanged<PathOption> onSelectAlternative;
  final VoidCallback? onSeeAllRoutes;

  const RoutePreviewSheet({
    super.key,
    required this.mode,
    required this.data,
    this.alternatives = const [],
    required this.destinationLabel,
    this.stageName,
    this.stageRoutes = const [],
    required this.loading,
    required this.error,
    required this.scrollController,
    required this.onStartJourney,
    required this.onRetry,
    required this.onSelectAlternative,
    this.onSeeAllRoutes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      key: const Key('routePreviewSheet'),
      color: NaviColors.surface(isDark),
      elevation: 12,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            height: 20,
            alignment: Alignment.center,
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: NaviColors.dividerC(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                NaviSpacing.xl,
                NaviSpacing.xs,
                NaviSpacing.xl,
                NaviSpacing.lg + bottomInset,
              ),
              children: [
                if (loading)
                  _Skeleton(isDark: isDark)
                else if (error)
                  _ErrorState(isDark: isDark, onRetry: onRetry)
                else if (data != null)
                  _ready(context, isDark, data!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ready(BuildContext context, bool isDark, RoutePreviewData data) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final bannerText = mode == RoutePreviewMode.stage
        ? 'Walk to ${stageName ?? destinationLabel}'
        : data.boardingText;

    final metrics = <RoutePreviewMetric>[
      if (data.firstWalk != null) data.firstWalk!,
      if (data.ride != null) data.ride!,
      if (data.lastWalk != null) data.lastWalk!,
    ];

    return AnimatedSwitcher(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey(
            '${data.routeLabel}_${data.title}_${data.totalDuration.inSeconds}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _TintPill(
                icon: mode == RoutePreviewMode.stage
                    ? Icons.directions_walk
                    : data.hasRide
                        ? Icons.directions_bus
                        : Icons.directions_walk,
                label: mode == RoutePreviewMode.stage
                    ? 'Walking'
                    : data.routeLabel ?? 'Route',
              ),
              const Spacer(),
              _TintPill(
                icon: Icons.schedule,
                label: RoutePreviewData.formatDuration(data.totalDuration),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: NaviType.uiFontFamily,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: NaviColors.textPrimary(isDark),
            ),
          ),
          if (data.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              data.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: NaviType.uiFontFamily,
                fontSize: 14,
                color: NaviColors.textSecondary(isDark),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _MetricsRow(metrics: metrics, isDark: isDark),
          if (data.transferCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              data.transferCount == 1
                  ? '1 transfer'
                  : '${data.transferCount} transfers',
              style: TextStyle(
                fontFamily: NaviType.uiFontFamily,
                fontSize: 13,
                color: NaviColors.textSecondary(isDark),
              ),
            ),
          ],
          if (bannerText != null) ...[
            const SizedBox(height: 16),
            _Banner(text: bannerText, isDark: isDark),
          ],
          const SizedBox(height: 16),
          _StartButton(onPressed: onStartJourney),
          if (mode == RoutePreviewMode.destination &&
              alternatives.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeading(
              title: 'Other Routes',
              isDark: isDark,
              trailing: onSeeAllRoutes == null
                  ? null
                  : InkWell(
                      onTap: onSeeAllRoutes,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'See all →',
                          style: TextStyle(
                            fontFamily: NaviType.uiFontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: RoutePreviewTheme.emerald,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < alternatives.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _AlternativeCard(
                alternative: alternatives[i],
                isDark: isDark,
                onTap: onSelectAlternative,
              ),
            ],
          ],
          if (mode == RoutePreviewMode.stage) ...[
            const SizedBox(height: 24),
            _SectionHeading(
              title: 'Routes from this stage',
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            if (stageRoutes.isEmpty)
              Text(
                'No routes recorded for this stage yet.',
                style: TextStyle(
                  fontFamily: NaviType.uiFontFamily,
                  fontSize: 13,
                  color: NaviColors.textSecondary(isDark),
                ),
              )
            else
              for (var i = 0; i < stageRoutes.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _StageRouteCard(summary: stageRoutes[i], isDark: isDark),
              ],
          ],
        ],
      ),
    );
  }
}

/// A route pill / time chip in the emerald 12% tint.
class _TintPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TintPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: RoutePreviewTheme.emeraldTint(),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: RoutePreviewTheme.emerald),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: NaviType.uiFontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: RoutePreviewTheme.emerald,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final List<RoutePreviewMetric> metrics;
  final bool isDark;

  const _MetricsRow({required this.metrics, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: NaviSpacing.md),
              color: NaviColors.dividerC(isDark),
            ),
          Expanded(child: _MetricColumn(metric: metrics[i], isDark: isDark)),
        ],
      ],
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final RoutePreviewMetric metric;
  final bool isDark;

  const _MetricColumn({required this.metric, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              metric.kind == RoutePreviewMetricKind.walk
                  ? Icons.directions_walk
                  : Icons.directions_bus,
              size: 16,
              color: RoutePreviewTheme.emerald,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                metric.time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: NaviType.uiFontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: NaviColors.textPrimary(isDark),
                ),
              ),
            ),
          ],
        ),
        if (metric.detail != null)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 1),
            child: Text(
              metric.detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: NaviType.uiFontFamily,
                fontSize: 12,
                color: NaviColors.textSecondary(isDark),
              ),
            ),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final bool isDark;

  const _Banner({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: RoutePreviewTheme.bannerTint(),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 18, color: RoutePreviewTheme.emerald),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: NaviType.uiFontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: NaviColors.textPrimary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _StartButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.play_arrow, color: Colors.white, size: 22),
        label: const Text(
          'Start Journey',
          style: TextStyle(
            fontFamily: NaviType.uiFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: RoutePreviewTheme.emerald,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final bool isDark;
  final Widget? trailing;

  const _SectionHeading({
    required this.title,
    required this.isDark,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: NaviType.uiFontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: NaviColors.textPrimary(isDark),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _AlternativeCard extends StatelessWidget {
  final RoutePreviewAlternative alternative;
  final bool isDark;
  final ValueChanged<PathOption> onTap;

  const _AlternativeCard({
    required this.alternative,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NaviColors.surface(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: NaviColors.dividerC(isDark)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onTap(alternative.option),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TintPill(
                          icon: alternative.routeLabel == 'Walking'
                              ? Icons.directions_walk
                              : Icons.directions_bus,
                          label: alternative.routeLabel,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            alternative.timeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: NaviType.uiFontFamily,
                              fontSize: 12,
                              color: NaviColors.textSecondary(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alternative.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: NaviType.uiFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: NaviColors.textPrimary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              if (alternative.fareLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  alternative.fareLabel!,
                  style: TextStyle(
                    fontFamily: NaviType.uiFontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NaviColors.textSecondary(isDark),
                  ),
                ),
              ],
              Icon(Icons.chevron_right,
                  size: 20, color: NaviColors.textSecondary(isDark)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageRouteCard extends StatelessWidget {
  final StageRouteSummary summary;
  final bool isDark;

  const _StageRouteCard({required this.summary, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final headsign = summary.headsign.trim();
    final showHeadsign =
        headsign.isNotEmpty && !headsign.toLowerCase().contains('not recorded');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: NaviColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NaviColors.dividerC(isDark)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _TintPill(
            icon: Icons.directions_bus,
            label: 'Route ${summary.routeNumber}',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeadsign)
                  Text(
                    '→ $headsign',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NaviType.uiFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NaviColors.textPrimary(isDark),
                    ),
                  ),
                if (showHeadsign) const SizedBox(height: 2),
                Text(
                  summary.headwayText,
                  maxLines: 2,
                  style: TextStyle(
                    fontFamily: NaviType.uiFontFamily,
                    fontSize: 12,
                    color: NaviColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;

  const _ErrorState({required this.isDark, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.route_outlined,
              size: 32, color: NaviColors.textSecondary(isDark)),
          const SizedBox(height: 12),
          Text(
            "We couldn't build this route.",
            style: TextStyle(
              fontFamily: NaviType.uiFontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: NaviColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check your connection and try again.',
            style: TextStyle(
              fontFamily: NaviType.uiFontFamily,
              fontSize: 14,
              color: NaviColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: RoutePreviewTheme.emerald,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontFamily: NaviType.uiFontFamily,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatefulWidget {
  final bool isDark;

  const _Skeleton({required this.isDark});

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduced motion: a static skeleton, never a sweep.
    if (!MediaQuery.of(context).disableAnimations) {
      _controller.repeat();
    }
  }

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
        if (MediaQuery.of(context).disableAnimations) return child!;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = _controller.value;
            return LinearGradient(
              begin: Alignment(t * 2 - 1.5, 0),
              end: Alignment(t * 2 - 0.5, 0),
              colors: widget.isDark
                  ? const [
                      Color(0xFF2A2D31),
                      Color(0xFF3A3E43),
                      Color(0xFF2A2D31),
                    ]
                  : const [
                      Color(0xFFEDEAE3),
                      Color(0xFFF7F5F0),
                      Color(0xFFEDEAE3),
                    ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _SkeletonBlock(width: 96, height: 32, radius: 16),
              Spacer(),
              _SkeletonBlock(width: 84, height: 32, radius: 16),
            ],
          ),
          const SizedBox(height: 16),
          const _SkeletonBlock(width: 230, height: 22),
          const SizedBox(height: 8),
          const _SkeletonBlock(width: 120, height: 12),
          const SizedBox(height: 20),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBlock(width: 64, height: 18),
                      SizedBox(height: 6),
                      _SkeletonBlock(width: 46, height: 10),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          const _SkeletonBlock(width: double.infinity, height: 48),
          const SizedBox(height: 18),
          const _SkeletonBlock(width: double.infinity, height: 52),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2D31) : const Color(0xFFEDEAE3),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
