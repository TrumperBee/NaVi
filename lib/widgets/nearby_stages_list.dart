import 'package:flutter/material.dart';

import '../design/navi_colors.dart';
import '../design/navi_typography.dart';
import '../models/transport_models.dart';
import '../utils/distance_formatter.dart';
import 'route_badge.dart';

/// A row model for the nearby-stages list.
///
/// [distanceMeters] is `0` when the user has no fix (no GPS/location
/// permission), in which case the row renders without a distance suffix.
class NearbyStageEntry {
  final StageModel stage;
  final double distanceMeters;

  const NearbyStageEntry({required this.stage, this.distanceMeters = 0});
}

/// The secondary, revealed-on-drag list of stages.
///
/// Rows keep the flat ListTile style but are restyled to the [NaviType]
/// tokens, and route numbers render as [RouteBadge]s so the list reads
/// consistently with the hero "Go" card above it.
class NearbyStagesList extends StatelessWidget {
  final List<NearbyStageEntry> stages;
  final ValueChanged<StageModel>? onStageTap;

  const NearbyStagesList({super.key, required this.stages, this.onStageTap});

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final entry in stages)
          _NearbyStageRow(
            entry: entry,
            onTap: () => onStageTap?.call(entry.stage),
          ),
      ],
    );
  }
}

class _NearbyStageRow extends StatelessWidget {
  final NearbyStageEntry entry;
  final VoidCallback onTap;

  const _NearbyStageRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final distanceLabel = entry.distanceMeters > 0
        ? '${DistanceFormatter.format(entry.distanceMeters)} away'
        : '';
    final subtitleParts = <String>[
      if (entry.stage.corridor.isNotEmpty) entry.stage.corridor,
      if (distanceLabel.isNotEmpty) distanceLabel,
    ];
    final routes = entry.stage.routes.take(2).toList();

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: NaviColors.transitGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.directions_bus,
          color: NaviColors.transitGreen,
          size: 18,
        ),
      ),
      title: Text(
        entry.stage.name,
        style: NaviType.cardTitle.copyWith(
          color: NaviColors.textPrimary(
              Theme.of(context).brightness == Brightness.dark),
        ),
      ),
      subtitle: Text(
        subtitleParts.join(' · '),
        style: NaviType.caption.copyWith(
          color: NaviColors.textSecondary(
              Theme.of(context).brightness == Brightness.dark),
        ),
      ),
      trailing: routes.isNotEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [RouteBadgeRow(routeNumbers: routes)],
            )
          : null,
      onTap: onTap,
    );
  }
}