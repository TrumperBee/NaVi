import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';

/// Tokens that are specific to the Route Preview (pre-trip) screen.
///
/// Everything else comes from [NaviColors] / `NaviType`. The only value that
/// has no design-system token yet is the destination-pin red, so it lives here
/// rather than being repeated at call sites.
class RoutePreviewTheme {
  const RoutePreviewTheme._();

  /// Destination pin / marker red (mock-up spec: #C62828).
  static const Color destinationRed = Color(0xFFC62828);

  /// Ride leg colour — the brand emerald.
  static const Color emerald = NaviColors.transitGreen;

  /// 12% emerald wash behind the route pill and the total-time chip.
  static Color emeraldTint() => emerald.withValues(alpha: 0.12);

  /// Slightly stronger 10% wash used by the boarding info banner.
  static Color bannerTint() => emerald.withValues(alpha: 0.10);

  /// Map style tokens for the preview route line.
  static const double rideWidth = 6.0;
  static const double rideCasingWidth = 2.0;
  static const double walkWidth = 4.0;
}
