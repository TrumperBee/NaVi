import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';

/// Color and metric tokens for the Active Navigation screen.
///
/// The screen is intentionally "hard" — a near-black instruction banner over
/// the map and a white sheet — so the values live here instead of being
/// scattered through the widgets. Brand accents come from [NaviColors]; the
/// dark banner is the same in both themes.
class ActiveNavTheme {
  const ActiveNavTheme._();

  /// Instruction banner background (same in light and dark).
  static const Color banner = Color(0xFF12161C);

  /// Primary action / "current step" accent.
  static const Color emerald = NaviColors.transitGreen;

  /// GPS / remaining-route blue.
  static const Color blue = NaviColors.signalBlue;

  /// Destructive action (End Journey).
  static const Color red = Color(0xFFC62828);

  /// Proximity alerts.
  static const Color amber = NaviColors.alertAmber;

  /// The journey timeline card sits on the warm canvas, not on white.
  static const Color timelineBackground = NaviColors.canvasLight;

  /// 12% emerald tint used behind the route/bus tile and voice-on states.
  static Color emeraldTint([double opacity = 0.12]) =>
      emerald.withValues(alpha: opacity);

  /// 14% amber tint for the proximity strip.
  static Color amberTint([double opacity = 0.14]) =>
      amber.withValues(alpha: opacity);

  /// Instruction banner height.
  static const double bannerHeight = 76;

  /// Height of the floating round map controls.
  static const double controlSize = 44;

  /// The collapsed sheet shows the current step plus the next two.
  static const int collapsedFutureSteps = 2;
}
