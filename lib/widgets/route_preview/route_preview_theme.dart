import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';
import '../../services/polyline_renderer.dart';

/// Tokens that are specific to the Route Preview (pre-trip) screen.
///
/// Everything else comes from [NaviColors] / `NaviType`. The destination-pin
/// red is aliased here because Route Preview uses it as a theme token; the
/// map annotation painter reads the same colour from [NaviColors].
class RoutePreviewTheme {
  const RoutePreviewTheme._();

  /// Destination pin / marker red (mock-up spec: #C62828).
  static const Color destinationRed = NaviColors.destinationPin;

  /// Brand emerald — accents only (pills, banner wash, boarding pin).
  static const Color emerald = NaviColors.transitGreen;

  /// 12% emerald wash behind the route pill and the total-time chip.
  static Color emeraldTint() => emerald.withValues(alpha: 0.12);

  /// Slightly stronger 10% wash used by the boarding info banner.
  static Color bannerTint() => emerald.withValues(alpha: 0.10);

  /// Map style tokens for the preview route line. The line itself is drawn by
  /// [PolylineRendererService] (one solid blue route style); these mirror its
  /// weights so sheet/legend call sites stay in sync.
  static const double rideWidth = PolylineRendererService.rideWidth;
  static const double rideCasingWidth =
      PolylineRendererService.casingExtraWidth;
  static const double walkWidth = PolylineRendererService.walkWidth;
}
