import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';
import '../../design/navi_typography.dart';
import 'active_nav_data.dart';
import 'active_nav_theme.dart';

/// The journey timeline: a connected vertical line with one row per step.
///
/// States are explicit and never conveyed by opacity:
/// * completed — emerald check, normal primary text
/// * current   — emerald filled marker, bold title, "Now" in emerald
/// * upcoming  — outlined marker, secondary text at full contrast
///
/// When the sheet is expanded, the ride rows also carry the intermediate
/// "N stops" row, which reveals the recorded stop names inline.
class NavTimelineCard extends StatelessWidget {
  final List<NavTimelineStep> steps;
  final ActiveNavData data;
  final bool expanded;
  final bool isDark;

  const NavTimelineCard({
    super.key,
    required this.steps,
    required this.data,
    required this.expanded,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final background =
        isDark ? NaviColors.canvasDark : ActiveNavTheme.timelineBackground;

    // Flatten steps into rows so the vertical line can be drawn continuously
    // across the optional "N stops" row.
    final rows = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      rows.add(NavTimelineRow(step: step, isDark: isDark));
      final stops = step.stopCount;
      if (expanded &&
          step.kind == NavTimelineKind.board &&
          stops != null &&
          stops > 0) {
        rows.add(NavStopsRow(
          segmentIndex: step.segmentIndex,
          stopCount: stops,
          names: data.stopNamesFor(step.segmentIndex),
          isDark: isDark,
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            _WithConnector(
              isFirst: i == 0,
              isLast: i == rows.length - 1,
              color: NaviColors.dividerC(isDark),
              child: rows[i],
            ),
        ],
      ),
    );
  }
}

/// Draws the vertical timeline line through a row (top half, bottom half) so
/// consecutive rows read as one continuous line.
class _WithConnector extends StatelessWidget {
  final Widget child;
  final bool isFirst;
  final bool isLast;
  final Color color;

  const _WithConnector({
    required this.child,
    required this.isFirst,
    required this.isLast,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          bottom: 0,
          left: 12,
          child: Column(
            children: [
              Expanded(
                child: isFirst
                    ? const SizedBox(width: 2)
                    : Container(width: 2, color: color),
              ),
              Expanded(
                child: isLast
                    ? const SizedBox(width: 2)
                    : Container(width: 2, color: color),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// One step row: marker on the line, title + subtitle, trailing time.
class NavTimelineRow extends StatelessWidget {
  final NavTimelineStep step;
  final bool isDark;

  const NavTimelineRow({
    super.key,
    required this.step,
    required this.isDark,
  });

  /// Every row is the same height so the line and the trailing column never
  /// jitter as states change.
  static const double rowHeight = 40;

  @override
  Widget build(BuildContext context) {
    final isCurrent = step.state == NavStepState.current;
    final isCompleted = step.state == NavStepState.completed;
    final titleColor = isCurrent || isCompleted
        ? NaviColors.textPrimary(isDark)
        : NaviColors.textSecondary(isDark);
    final subtitleColor = NaviColors.textSecondary(isDark);

    return SizedBox(
      height: rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: 26,
            height: rowHeight,
            child: Center(child: _marker(context)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: NaviType.uiFontFamily,
                    fontSize: 16,
                    height: 1.1,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                if (step.subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    step.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NaviType.uiFontFamily,
                      fontSize: 13,
                      height: 1.1,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: _trailing(),
          ),
        ],
      ),
    );
  }

  Widget _marker(BuildContext context) {
    final background =
        isDark ? NaviColors.canvasDark : ActiveNavTheme.timelineBackground;
    switch (step.state) {
      case NavStepState.completed:
        return Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child:
              const Icon(Icons.check, size: 15, color: ActiveNavTheme.emerald),
        );
      case NavStepState.current:
        return Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: ActiveNavTheme.emerald,
            shape: BoxShape.circle,
          ),
          child: Icon(_icon, size: 14, color: Colors.white),
        );
      case NavStepState.upcoming:
        return Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(color: NaviColors.dividerC(isDark)),
          ),
          child: Icon(
            _icon,
            size: 13,
            color: NaviColors.textSecondary(isDark),
          ),
        );
    }
  }

  IconData get _icon {
    switch (step.kind) {
      case NavTimelineKind.walk:
        return Icons.directions_walk;
      case NavTimelineKind.board:
        return Icons.directions_bus;
      case NavTimelineKind.alight:
        return Icons.logout;
    }
  }

  Widget _trailing() {
    if (step.state == NavStepState.completed) return const SizedBox.shrink();
    final isCurrent = step.state == NavStepState.current;
    final label = isCurrent
        ? 'Now'
        : (step.eta == null ? '' : ActiveNavData.formatClock(step.eta!));
    return Text(
      label,
      textAlign: TextAlign.right,
      maxLines: 1,
      style: TextStyle(
        fontFamily: NaviType.uiFontFamily,
        fontSize: 13,
        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
        color: isCurrent
            ? ActiveNavTheme.emerald
            : NaviColors.textSecondary(isDark),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// The intermediate "N stops" row shown between boarding and alighting once
/// the sheet is expanded. Tapping reveals the stop names recorded in the GTFS
/// route direction; when none were recorded the row stays informational.
class NavStopsRow extends StatefulWidget {
  final int segmentIndex;
  final int stopCount;
  final List<String> names;
  final bool isDark;

  const NavStopsRow({
    super.key,
    required this.segmentIndex,
    required this.stopCount,
    required this.names,
    required this.isDark,
  });

  @override
  State<NavStopsRow> createState() => _NavStopsRowState();
}

class _NavStopsRowState extends State<NavStopsRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final label =
        widget.stopCount == 1 ? '1 stop' : '${widget.stopCount} stops';
    final canOpen = widget.names.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: InkWell(
            onTap: canOpen ? () => setState(() => _open = !_open) : null,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                const SizedBox(width: 26),
                const SizedBox(width: 10),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: NaviColors.textSecondary(isDark),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NaviType.uiFontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: NaviColors.textSecondary(isDark),
                    ),
                  ),
                ),
                if (canOpen)
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: NaviColors.textSecondary(isDark),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(left: 52, right: 8, bottom: 8),
            child: Text(
              widget.names.join(' · '),
              style: TextStyle(
                fontFamily: NaviType.uiFontFamily,
                fontSize: 13,
                height: 1.35,
                color: NaviColors.textSecondary(isDark),
              ),
            ),
          ),
      ],
    );
  }
}
