import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';
import '../../design/navi_typography.dart';
import '../../features/journey/models/journey_models.dart';
import '../../services/settings_service.dart';

/// The one saved-places sheet used by both the header's "See all →" link and
/// the "Saved" quick tile.
///
/// It reads the same Home / Work / Campus places already persisted by
/// [SettingsService] — there is no separate favourites system behind it.
/// Tapping a row hands the destination back to the caller, which starts the
/// existing navigation flow.
class SavedPlacesSheet extends StatelessWidget {
  final List<SavedDestination> destinations;
  final ValueChanged<SavedDestination> onDestinationTap;

  const SavedPlacesSheet({
    super.key,
    required this.destinations,
    required this.onDestinationTap,
  });

  /// Opens the sheet over the current screen.
  static Future<void> show(
    BuildContext context, {
    required List<SavedDestination> destinations,
    required ValueChanged<SavedDestination> onDestinationTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SavedPlacesSheet(
        destinations: destinations,
        onDestinationTap: onDestinationTap,
      ),
    );
  }

  static String labelFor(SavedDestinationType type) {
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

  static IconData iconFor(SavedDestinationType type) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final rows = <Widget>[
      const _SheetHandle(),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Row(
          children: [
            const Icon(Icons.bookmark_border,
                size: 20, color: NaviColors.transitGreen),
            const SizedBox(width: 8),
            Text(
              'Saved places',
              style: TextStyle(
                fontFamily: NaviType.uiFontFamily,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: NaviColors.textPrimary(isDark),
              ),
            ),
          ],
        ),
      ),
    ];

    if (destinations.isEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Text(
          'No saved places yet. Tap the Home, Work or Campus tile to set one.',
          style: NaviType.body.copyWith(
            color: NaviColors.textSecondary(isDark),
          ),
        ),
      ));
    } else {
      for (final destination in destinations) {
        rows.add(_SavedPlaceRow(
          destination: destination,
          onTap: () {
            Navigator.of(context).pop();
            onDestinationTap(destination);
          },
        ));
      }
    }

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
      decoration: BoxDecoration(
        color: NaviColors.surface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: rows,
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
    );
  }
}

class _SavedPlaceRow extends StatelessWidget {
  final SavedDestination destination;
  final VoidCallback onTap;

  const _SavedPlaceRow({required this.destination, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = SavedPlacesSheet.labelFor(destination.type);
    final subtitle = SavedPlace(
      lat: destination.latitude,
      lng: destination.longitude,
      label: destination.label,
    ).displaySubtitle(title: title);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: NaviColors.transitGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  SavedPlacesSheet.iconFor(destination.type),
                  size: 20,
                  color: NaviColors.transitGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: NaviType.uiFontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: NaviColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: NaviType.uiFontFamily,
                        fontSize: 13,
                        color: NaviColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: NaviColors.textSecondary(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
