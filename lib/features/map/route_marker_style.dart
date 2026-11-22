import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';

/// Visual contract for the three map indicators used on a confirmed journey.
///
/// Keeping the shapes and colours in one design-level place lets the marker
/// painter and the focused tests assert the same rules:
/// * departure: emerald disc with a white ring, never moved by GPS,
/// * destination: white pin with a red outline, bottom-anchored on the point,
/// * GPS: signal blue with a translucent accuracy ring, the only moving mark.
enum RouteMarkerShape { circle, pin }

class RouteMarkerStyle {
  const RouteMarkerStyle._();

  static const RouteMarkerShape departureShape = RouteMarkerShape.circle;
  static const Color departureFill = NaviColors.transitGreen;
  static const Color departureRing = Colors.white;
  static const double departureRadius = 9;
  static const double departureRingWidth = 3;

  static const RouteMarkerShape destinationShape = RouteMarkerShape.pin;
  static const Color destinationOutline = NaviColors.destinationPin;
  static const Color destinationFill = Colors.white;
  static const double destinationOutlineWidth = 2.5;

  /// Exact GPS blue required by the navigation spec (#1A73E8).
  static const Color gpsPuck = NaviColors.signalBlue;
  static const double gpsAccuracyFillOpacity = 0.18;
  static const double gpsAccuracyBorderOpacity = 0.55;
}
