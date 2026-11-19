import 'package:flutter/material.dart';

import '../design/navi_colors.dart';
import '../design/navi_spacing.dart';
import '../design/navi_typography.dart';
import '../features/journey/models/journey_models.dart';
import '../services/settings_service.dart';

/// Horizontally scrollable Home / Work / Campus quick-go chips.
///
/// Promoted directly beneath the search bar on the homepage. Chips are kept
/// deliberately quiet — canvas background with a hairline divider border — so
/// the hero "Go" card remains the one bold element on screen. Missing
/// destinations degrade into a muted "Add …" chip that keeps the existing
/// set-destination flow reachable.
///
/// Each set chip is a two-line pill: the slot name ("Home" / "Work" /
/// "Campus") as the title with its icon, and a specific address line
/// underneath — the street/neighbourhood from the reverse geocode, or the
/// coordinates when nothing specific was found
/// ([SavedPlace.displaySubtitle]) — so two places saved at different spots
/// can never read the same. Tapping a set chip starts routing to it;
/// long-press opens the edit/clear dialog.
///
/// The row is 56dp tall: the visual chip is 48dp but the ink/tap target spans
/// the full row height so every chip meets the 44x44 minimum touch target.
class QuickGoRow extends StatelessWidget {
  final List<SavedDestination> destinations;
  final ValueChanged<SavedDestination> onTap;

  /// Long-press on a saved chip opens the edit/relocate flow for that place.
  final ValueChanged<SavedDestination>? onEdit;
  final VoidCallback? onAddHome;
  final VoidCallback? onAddWork;
  final VoidCallback? onAddCampus;

  const QuickGoRow({
    super.key,
    required this.destinations,
    required this.onTap,
    this.onEdit,
    this.onAddHome,
    this.onAddWork,
    this.onAddCampus,
  });

  static const double rowHeight = 56;
  static const double _chipHeight = 48;
  static const double _hitPadding = (rowHeight - _chipHeight) / 2;

  /// The slot name a pill titles itself with — always the slot, never the
  /// geocoded address, so pills stay distinguishable at a glance.
  static String titleFor(SavedDestinationType type) {
    switch (type) {
      case SavedDestinationType.home:
        return 'Home';
      case SavedDestinationType.work:
        return 'Work';
      case SavedDestinationType.campus:
        return 'Campus';
      case SavedDestinationType.frequent:
        return 'Location';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: NaviSpacing.sm),
        itemBuilder: (context, index) {
          final item = items[index];
          final destination = item.$1;
          if (destination != null) {
            final title = titleFor(destination.type);
            final subtitle = SavedPlace(
              lat: destination.latitude,
              lng: destination.longitude,
              label: destination.label,
            ).displaySubtitle(title: title);
            return Align(
              alignment: Alignment.centerLeft,
              child: _QuickGoChip(
                icon: _iconFor(destination.type),
                title: title,
                subtitle: subtitle,
                onTap: () => onTap(destination),
                onLongPress: onEdit == null
                    ? null
                    : () => onEdit!(destination),
              ),
            );
          }
          final add = item.$2!;
          return Align(
            alignment: Alignment.centerLeft,
            child: _QuickGoChip(
              icon: add.icon,
              title: add.label,
              muted: true,
              onTap: add.onTap,
            ),
          );
        },
      ),
    );
  }

  List<(SavedDestination?, _AddItem?)> _buildItems() {
    final items = <(SavedDestination?, _AddItem?)>[];
    var hasHome = false;
    var hasWork = false;
    var hasCampus = false;

    for (final destination in destinations) {
      items.add((destination, null));
      switch (destination.type) {
        case SavedDestinationType.home:
          hasHome = true;
        case SavedDestinationType.work:
          hasWork = true;
        case SavedDestinationType.campus:
          hasCampus = true;
        case SavedDestinationType.frequent:
          break;
      }
    }

    if (!hasHome && onAddHome != null) {
      items.add((null, _AddItem(Icons.home, 'Add Home', onAddHome!)));
    }
    if (!hasWork && onAddWork != null) {
      items.add((null, _AddItem(Icons.work, 'Add Work', onAddWork!)));
    }
    if (!hasCampus && onAddCampus != null) {
      items.add((null, _AddItem(Icons.school, 'Add Campus', onAddCampus!)));
    }

    return items;
  }

  static IconData _iconFor(SavedDestinationType type) {
    switch (type) {
      case SavedDestinationType.home:
        return Icons.home;
      case SavedDestinationType.work:
        return Icons.work;
      case SavedDestinationType.campus:
        return Icons.school;
      case SavedDestinationType.frequent:
        return Icons.star;
    }
  }
}

class _AddItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddItem(this.icon, this.label, this.onTap);
}

class _QuickGoChip extends StatelessWidget {
  final IconData icon;

  /// Slot name shown as the pill's first line ("Home" / "Work" / "Campus"),
  /// or the full label for muted "Add …" chips.
  final String title;

  /// Address line under the title; null renders a single-line chip.
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool muted;

  const _QuickGoChip({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.onLongPress,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleStyle = NaviType.caption.copyWith(
      color: muted
          ? NaviColors.textSecondary(isDark)
          : NaviColors.textPrimary(isDark),
      fontWeight: FontWeight.w600,
    );
    final chip = Container(
      height: QuickGoRow._chipHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: NaviColors.canvas(isDark),
        borderRadius:
            BorderRadius.circular(QuickGoRow._chipHeight / 2),
        border: Border.all(color: NaviColors.dividerC(isDark), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: NaviColors.transitGreen),
          const SizedBox(width: 6),
          if (subtitle == null)
            Text(title, style: titleStyle)
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle!,
                  key: const ValueKey('quickGoSubtitle'),
                  style: NaviType.caption.copyWith(
                    color: NaviColors.textSecondary(isDark),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      child: SizedBox(
        height: QuickGoRow.rowHeight,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(QuickGoRow._chipHeight / 2),
            child: Padding(
              // Hit area = 48 visual + 8dp of vertical padding = 56dp.
              padding: const EdgeInsets.symmetric(vertical: QuickGoRow._hitPadding),
              child: chip,
            ),
          ),
        ),
      ),
    );
  }
}