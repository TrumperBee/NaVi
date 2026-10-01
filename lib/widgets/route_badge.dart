import 'package:flutter/material.dart';

import '../design/navi_colors.dart';
import '../design/navi_spacing.dart';
import '../design/navi_typography.dart';

/// A PSV-yellow route number badge.
///
/// Deliberately rectangular (4dp radius) rather than a capsule pill, echoing
/// the physical route boards found at Nairobi stages so it reads as a real
/// route identifier, not a generic tag.
class RouteBadge extends StatelessWidget {
  final String routeNumber;

  const RouteBadge({super.key, required this.routeNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: NaviInsets.badge,
      decoration: BoxDecoration(
        color: NaviColors.psvYellow,
        borderRadius: BorderRadius.circular(NaviRadius.badge),
      ),
      child: Text(
        routeNumber,
        style: NaviType.caption.copyWith(
          color: NaviColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A row of [RouteBadge]s, wrapping when space is constrained.
class RouteBadgeRow extends StatelessWidget {
  final List<String> routeNumbers;

  const RouteBadgeRow({super.key, required this.routeNumbers});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: NaviSpacing.badgeGap,
      runSpacing: NaviSpacing.badgeGap,
      children: [
        for (final routeNumber in routeNumbers)
          RouteBadge(routeNumber: routeNumber),
      ],
    );
  }
}