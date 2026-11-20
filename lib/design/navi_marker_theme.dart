import 'package:flutter/material.dart';

import 'navi_colors.dart';

/// Ambient theme for markers that are baked into Mapbox style images.
///
/// Route Preview owns the preview map annotations even though Home keeps the
/// single live MapWidget alive, so the preview screen publishes its brightness
/// here before those images are drawn. Keeping the colour decision in the
/// design layer avoids a widget -> map -> widget dependency cycle.
class NaviMarkerTheme {
  const NaviMarkerTheme._();

  /// Set by Route Preview from `Theme.of(context).brightness`.
  static bool isDark = false;

  /// Pin geometry, in logical dp. The tip is anchored to the map coordinate.
  static const pinHeight = 32.0;
  static const pinWidth = 22.0;

  /// Label chip geometry, in logical dp/sp.
  static const chipFontSize = 13.0;
  static const chipMaxWidth = 180.0;
  static const chipHorizontalPadding = 8.0;
  static const chipVerticalPadding = 5.0;
  static const chipTailHeight = 5.0;
  static const chipGap = 3.0;

  /// Label chip behind a preview pin: white by day, dark grey at night.
  static Color get chipBackground =>
      isDark ? const Color(0xFF2B3037) : Colors.white;

  /// Chip text flips to white on the dark chip so it keeps the same contrast.
  static Color get chipText =>
      isDark ? NaviColors.textPrimaryDark : NaviColors.textPrimaryLight;

  /// Barely-there outline so a white chip still reads over a pale map tile.
  static Color get chipBorder =>
      isDark ? const Color(0x80FFFFFF) : const Color(0x22000000);
}
