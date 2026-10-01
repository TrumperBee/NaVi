import 'package:flutter/material.dart';

/// Central color palette for the NaVi design system.
///
/// Rules:
/// - `psvYellow` is the one bold accent, reserved for route badges.
/// - `signalBlue` is reserved exclusively for GPS/location elements.
///
/// The palette carries explicit light and dark token sets. Call sites that
/// live on a themed surface (custom sheets, cards, painted text) should pass
/// the ambient brightness from `Theme.of(context).brightness` into the
/// `canvas`/`surface`/`textPrimary`/`textSecondary` helpers; brand tokens
/// (`psvYellow`, `transitGreen`, `signalBlue`, `alertAmber`) are the same in
/// both themes and must never be darkened or inverted.
class NaviColors {
  const NaviColors._();

  // ==================== BRAND TOKENS (theme-independent) ====================

  /// Primary text, hero card background.
  static const ink = Color(0xFF12161C);

  /// Route badges — the one bold accent.
  static const psvYellow = Color(0xFFFFC627);

  /// Primary CTA only.
  static const transitGreen = Color(0xFF00875A);

  /// GPS dot / live tracking only.
  static const signalBlue = Color(0xFF1A73E8);

  /// Proximity alerts.
  static const alertAmber = Color(0xFFF59E0B);

  // ==================== LIGHT THEME ====================

  /// Background, warm off-white.
  static const canvasLight = Color(0xFFF6F4EF);

  /// Surface cards / sheets.
  static const surfaceLight = Color(0xFFFFFFFF);

  /// Primary text.
  static const textPrimaryLight = Color(0xFF12161C);

  /// Secondary/caption text.
  ///
  /// Kept at 5.4:1 on `canvasLight` (not the spec's #6B7280 at 4.38:1) so
  /// small secondary copy meets WCAG AA (4.5:1).
  static const textSecondaryLight = Color(0xFF5D6570);

  /// Hairline dividers.
  static const divider = Color(0xFFE5E1D8);

  // ==================== DARK THEME ====================

  /// Background.
  static const canvasDark = Color(0xFF121212);

  /// Surface cards / sheets.
  static const surfaceDark = Color(0xFF1E1E1E);

  /// Primary text.
  static const textPrimaryDark = Color(0xFFF9FAFB);

  /// Secondary/caption text.
  static const textSecondaryDark = Color(0xFFB0B3B8);

  /// Hairline dividers.
  static const dividerDark = Color(0xFF3A3D40);

  // ==================== THEME HELPERS ====================

  /// Secondary text, still the legacy AA-compliant alias.
  static const muted = textSecondaryLight;

  /// Background.
  static Color canvas(bool isDark) => isDark ? canvasDark : canvasLight;

  /// Surface for cards and sheets.
  static Color surface(bool isDark) => isDark ? surfaceDark : surfaceLight;

  /// Primary text.
  static Color textPrimary(bool isDark) =>
      isDark ? textPrimaryDark : textPrimaryLight;

  /// Secondary/caption text.
  static Color textSecondary(bool isDark) =>
      isDark ? textSecondaryDark : textSecondaryLight;

  /// Hairline dividers.
  static Color dividerC(bool isDark) => isDark ? dividerDark : divider;
}