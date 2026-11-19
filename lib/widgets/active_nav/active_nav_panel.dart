import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';
import '../../design/navi_typography.dart';
import 'active_nav_data.dart';
import 'active_nav_theme.dart';
import 'journey_summary.dart';
import 'journey_timeline.dart';

/// The bottom panel of the Active Navigation screen.
///
/// Three fixed zones so nothing jumps while the numbers update:
/// 1. the summary row (remaining time / distance / active mode),
/// 2. the scrolling journey timeline — the only draggable region,
/// 3. the action row pinned above the system inset.
class ActiveNavPanel extends StatelessWidget {
  final ActiveNavData data;
  final ScrollController scrollController;
  final bool expanded;
  final VoidCallback onEndTrip;

  const ActiveNavPanel({
    super.key,
    required this.data,
    required this.scrollController,
    required this.expanded,
    required this.onEndTrip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final steps = expanded ? data.timeline : data.collapsedTimeline;

    return Material(
      key: const Key('activeNavPanel'),
      color: NaviColors.surface(isDark),
      elevation: 16,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            height: 16,
            child: Center(
              child: _Handle(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: NavSummaryRow(data: data, isDark: isDark),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              children: [
                NavTimelineCard(
                  steps: steps,
                  data: data,
                  expanded: expanded,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8 + bottomInset),
            child: _EndJourneyButton(onPressed: () => _confirmEnd(context)),
          ),
        ],
      ),
    );
  }

  /// Ending a journey is destructive, so it always passes through a confirm
  /// dialog before [onEndTrip] runs.
  Future<void> _confirmEnd(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End this journey?'),
        content: const Text('Navigation will stop and your progress will not '
            'be saved as a completed journey.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: ActiveNavTheme.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Journey'),
          ),
        ],
      ),
    );
    if (confirmed == true) onEndTrip();
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: NaviColors.dividerC(isDark),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _EndJourneyButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _EndJourneyButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: ActiveNavTheme.red,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 20),
        label: const Text(
          'End Journey',
          style: TextStyle(
            fontFamily: NaviType.uiFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
