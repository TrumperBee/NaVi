import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';
import '../../design/navi_typography.dart';
import '../../features/journey/models/journey_models.dart';
import '../../services/settings_service.dart';

/// The single floating white panel at the top of the Home screen.
///
/// It holds, in order: the NaVi wordmark + signed-in avatar, the search field
/// with a locate button, the "Quick Go" heading, and the four shortcut tiles
/// (Home / Work / Campus / Saved).
///
/// The panel is presentation only — every value shown here is passed in from
/// [HomeScreen], which owns the saved-place storage and the navigation flow.
class HomeHeaderPanel extends StatelessWidget {
  /// Radius of the two bottom corners.
  static const double panelRadius = 28;

  /// Search field height / radius.
  static const double searchHeight = 52;
  static const double searchRadius = 26;

  /// Shortcut tile geometry.
  static const double tileHeight = 84;
  static const double tileRadius = 16;
  static const double tileGap = 8;

  /// Hint shown in the search field.
  static const String searchHint = 'Search for a stage or place...';

  /// Sub-label under the wordmark.
  static const String tagline = 'Navigate Nairobi';

  final String userInitial;
  final VoidCallback onAvatarTap;
  final VoidCallback onSearchTap;
  final VoidCallback onLocateTap;
  final VoidCallback onSeeAllQuickGo;
  final List<SavedDestination> destinations;
  final ValueChanged<SavedDestination> onDestinationTap;
  final ValueChanged<SavedDestinationType> onDestinationLongPress;
  final ValueChanged<SavedDestinationType> onSetDestination;
  final VoidCallback onSavedTap;

  const HomeHeaderPanel({
    super.key,
    required this.userInitial,
    required this.onAvatarTap,
    required this.onSearchTap,
    required this.onLocateTap,
    required this.onSeeAllQuickGo,
    required this.destinations,
    required this.onDestinationTap,
    required this.onDestinationLongPress,
    required this.onSetDestination,
    required this.onSavedTap,
  });

  SavedDestination? _destinationFor(SavedDestinationType type) {
    for (final destination in destinations) {
      if (destination.type == type) return destination;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = NaviColors.textPrimary(isDark);
    final secondary = NaviColors.textSecondary(isDark);

    return Container(
      decoration: BoxDecoration(
        color: NaviColors.surface(isDark),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(panelRadius)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBrandRow(primary, secondary),
          const SizedBox(height: 8),
          _buildSearchRow(context, secondary),
          const SizedBox(height: 6),
          _buildQuickGoHeading(primary),
          const SizedBox(height: 6),
          _buildTiles(),
        ],
      ),
    );
  }

  // ==================== ROW 1 — BRAND ====================

  Widget _buildBrandRow(Color primary, Color secondary) {
    return Row(
      children: [
        const Icon(Icons.location_on, color: NaviColors.transitGreen, size: 30),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NaVi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NaviType.wordmark.copyWith(color: primary),
              ),
              Text(
                tagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NaviType.caption.copyWith(
                  color: secondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _AvatarButton(initial: userInitial, onTap: onAvatarTap),
      ],
    );
  }

  // ==================== ROW 2 — SEARCH + LOCATE ====================

  Widget _buildSearchRow(BuildContext context, Color secondary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: searchHint,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSearchTap,
                borderRadius: BorderRadius.circular(searchRadius),
                child: Container(
                  height: searchHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: NaviColors.canvas(isDark),
                    borderRadius: BorderRadius.circular(searchRadius),
                    border: Border.all(color: NaviColors.dividerC(isDark)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 20, color: secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          searchHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: NaviType.uiFontFamily,
                            fontSize: 15,
                            color: secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 40dp visual circle inside a 48dp tap target.
        SizedBox(
          width: 48,
          height: 48,
          child: Semantics(
            button: true,
            label: 'Centre the map on my location',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onLocateTap,
                customBorder: const CircleBorder(),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: NaviColors.transitGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.my_location,
                      size: 20,
                      color: NaviColors.transitGreen,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== ROW 3 — QUICK GO ====================

  Widget _buildQuickGoHeading(Color primary) {
    return Row(
      children: [
        const Icon(Icons.bolt, size: 20, color: NaviColors.transitGreen),
        const SizedBox(width: 2),
        Text(
          'Quick Go',
          style: TextStyle(
            fontFamily: NaviType.uiFontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
        const Spacer(),
        _LinkButton(label: 'See all →', onTap: onSeeAllQuickGo),
      ],
    );
  }

  // ==================== ROW 4 — SHORTCUT TILES ====================

  Widget _buildTiles() {
    final home = _destinationFor(SavedDestinationType.home);
    final work = _destinationFor(SavedDestinationType.work);
    final campus = _destinationFor(SavedDestinationType.campus);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _QuickTile(
            icon: Icons.home,
            label: 'Home',
            caption: _captionFor(home, 'Home'),
            onTap: () => home == null
                ? onSetDestination(SavedDestinationType.home)
                : onDestinationTap(home),
            onLongPress: home == null
                ? null
                : () => onDestinationLongPress(SavedDestinationType.home),
          ),
        ),
        const SizedBox(width: tileGap),
        Expanded(
          child: _QuickTile(
            icon: Icons.work,
            label: 'Work',
            caption: _captionFor(work, 'Work'),
            onTap: () => work == null
                ? onSetDestination(SavedDestinationType.work)
                : onDestinationTap(work),
            onLongPress: work == null
                ? null
                : () => onDestinationLongPress(SavedDestinationType.work),
          ),
        ),
        const SizedBox(width: tileGap),
        Expanded(
          child: _QuickTile(
            icon: Icons.school,
            label: 'Campus',
            caption: _captionFor(campus, 'Campus'),
            onTap: () => campus == null
                ? onSetDestination(SavedDestinationType.campus)
                : onDestinationTap(campus),
            onLongPress: campus == null
                ? null
                : () => onDestinationLongPress(SavedDestinationType.campus),
          ),
        ),
        const SizedBox(width: tileGap),
        Expanded(
          child: _QuickTile(
            icon: Icons.bookmark_border,
            label: 'Saved',
            caption: destinations.isEmpty
                ? 'Tap to set'
                : '${destinations.length} saved',
            onTap: onSavedTap,
          ),
        ),
      ],
    );
  }

  /// The most specific saved address line, or "Tap to set" when the slot is
  /// empty. Never a hardcoded sample address.
  String _captionFor(SavedDestination? destination, String title) {
    if (destination == null) return 'Tap to set';
    return SavedPlace(
      lat: destination.latitude,
      lng: destination.longitude,
      label: destination.label,
    ).displaySubtitle(title: title);
  }
}

/// The 40dp emerald avatar with the signed-in user's first initial, inside a
/// 48dp tap target.
class _AvatarButton extends StatelessWidget {
  final String initial;
  final VoidCallback onTap;

  const _AvatarButton({required this.initial, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Semantics(
        button: true,
        label: 'Open your profile',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: NaviColors.transitGreen,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: NaviType.uiFontFamily,
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet emerald text link with a 48dp tall tap target.
class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LinkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: NaviType.uiFontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: NaviColors.transitGreen,
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the four equal shortcut tiles.
class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: '$label, $caption',
      child: Material(
        color: NaviColors.surface(isDark),
        borderRadius: BorderRadius.circular(HomeHeaderPanel.tileRadius),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(HomeHeaderPanel.tileRadius),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: HomeHeaderPanel.tileHeight),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HomeHeaderPanel.tileRadius),
              border: Border.all(color: NaviColors.dividerC(isDark)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: NaviColors.transitGreen),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NaviType.uiFontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: NaviColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: NaviType.uiFontFamily,
                    fontSize: 11,
                    color: NaviColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
