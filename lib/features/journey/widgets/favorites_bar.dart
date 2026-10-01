import 'package:flutter/material.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';

class FavoritesBar extends StatelessWidget {
  final List<SavedDestination> destinations;
  final ValueChanged<SavedDestination> onTap;

  /// Long-press on a saved card opens the edit/relocate flow for that place.
  final ValueChanged<SavedDestination>? onEdit;
  final VoidCallback? onAddHome;
  final VoidCallback? onAddWork;
  final VoidCallback? onAddCampus;

  const FavoritesBar({
    super.key,
    required this.destinations,
    required this.onTap,
    this.onEdit,
    this.onAddHome,
    this.onAddWork,
    this.onAddCampus,
  });

  @override
  Widget build(BuildContext context) {
    final hasAny = destinations.isNotEmpty ||
        onAddHome != null ||
        onAddWork != null ||
        onAddCampus != null;
    if (!hasAny) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'Quick Go',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _allItems.length,
            itemBuilder: (context, index) {
              final item = _allItems[index];
              if (item.$1 case final SavedDestination dest) {
                return _FavoriteCard(
                  dest: dest,
                  onTap: () => onTap(dest),
                  onLongPress: onEdit == null ? null : () => onEdit!(dest),
                );
              }
              final addData = item.$2!;
              return _AddCard(
                icon: addData.icon,
                label: addData.label,
                color: addData.color,
                onTap: addData.onTap,
              );
            },
          ),
        ),
      ],
    );
  }

  List<(SavedDestination?, _AddData?)> get _allItems {
    final items = <(SavedDestination?, _AddData?)>[];
    bool hasHome = false;
    bool hasWork = false;
    bool hasCampus = false;

    for (final dest in destinations) {
      items.add((dest, null));
      if (dest.type == SavedDestinationType.home) hasHome = true;
      if (dest.type == SavedDestinationType.work) hasWork = true;
      if (dest.type == SavedDestinationType.campus) hasCampus = true;
    }

    if (!hasHome && onAddHome != null) {
      items.add((
        null,
        _AddData(
          icon: Icons.home,
          label: 'Add Home',
          color: Colors.blue,
          onTap: onAddHome!,
        ),
      ));
    }
    if (!hasWork && onAddWork != null) {
      items.add((
        null,
        _AddData(
          icon: Icons.work,
          label: 'Add Work',
          color: Colors.orange,
          onTap: onAddWork!,
        ),
      ));
    }
    if (!hasCampus && onAddCampus != null) {
      items.add((
        null,
        _AddData(
          icon: Icons.school,
          label: 'Add Campus',
          color: Colors.purple,
          onTap: onAddCampus!,
        ),
      ));
    }

    return items;
  }
}

class _AddData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AddData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _FavoriteCard extends StatelessWidget {
  final SavedDestination dest;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FavoriteCard({
    required this.dest,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _iconColor, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              dest.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    switch (dest.type) {
      case SavedDestinationType.home:
        return Icons.home;
      case SavedDestinationType.campus:
        return Icons.school;
      case SavedDestinationType.work:
        return Icons.work;
      case SavedDestinationType.frequent:
        return Icons.star;
    }
  }

  Color get _iconColor {
    switch (dest.type) {
      case SavedDestinationType.home:
        return Colors.blue;
      case SavedDestinationType.campus:
        return Colors.purple;
      case SavedDestinationType.work:
        return Colors.orange;
      case SavedDestinationType.frequent:
        return Colors.amber;
    }
  }
}

class _AddCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}