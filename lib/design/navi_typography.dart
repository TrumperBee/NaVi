import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'navi_colors.dart';

/// Typographic scale for the NaVi design system.
///
/// Font family names map to the families registered by the `google_fonts`
/// package: `'Archivo Black'` is the single display face and `'Inter'` is the
/// UI face. Call [NaviType.ensureLoaded] once (e.g. from `main()`) so the
/// families are registered with the engine and these const styles resolve.
class NaviType {
  const NaviType._();

  /// The registered `google_fonts` family for the display face.
  static const displayFontFamily = 'Archivo Black';

  /// The registered `google_fonts` family for the UI face.
  static const uiFontFamily = 'Inter';

  /// Hero numeral — the one deliberate typographic moment on the homepage.
  static const heroNumeral = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 34,
    height: 1.0,
    color: NaviColors.ink,
  );

  static const title = TextStyle(
    fontFamily: uiFontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    color: NaviColors.ink,
  );

  static const cardTitle = TextStyle(
    fontFamily: uiFontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: NaviColors.ink,
  );

  static const body = TextStyle(
    fontFamily: uiFontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: NaviColors.muted,
  );

  static const caption = TextStyle(
    fontFamily: uiFontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: NaviColors.muted,
  );

  /// Registers the design system fonts with the engine so the const styles
  /// above actually resolve instead of falling back to the system default.
  ///
  /// The `google_fonts` getters return a [TextStyle] synchronously but kick
  /// off asynchronous font loading; [GoogleFonts.pendingFonts] waits until
  /// every requested family is registered before the first frame.
  static Future<void> ensureLoaded() async {
    GoogleFonts.archivoBlack();
    GoogleFonts.inter();
    await GoogleFonts.pendingFonts();
  }
}