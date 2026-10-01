import 'package:flutter/material.dart';

/// Spacing scale for the NaVi design system.
class NaviSpacing {
  const NaviSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;

  /// Gap between route badges laid out in a row.
  static const badgeGap = 6.0;
}

/// Corner radii for the NaVi design system.
class NaviRadius {
  const NaviRadius._();

  /// Route badge — rectangular, distinct from capsule pills.
  static const badge = 4.0;

  /// Standard cards.
  static const card = 12.0;

  /// The hero "Go" card.
  static const heroCard = 20.0;
}

/// Insets for the NaVi design system.
class NaviInsets {
  const NaviInsets._();

  static const badge = EdgeInsets.symmetric(
    horizontal: NaviSpacing.sm,
    vertical: NaviSpacing.xs,
  );

  static const card = EdgeInsets.all(NaviSpacing.lg);

  static const heroCard = EdgeInsets.all(NaviSpacing.xl);
}