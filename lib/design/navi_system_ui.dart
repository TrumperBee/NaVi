import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The status-bar style for NaVi's map-first screens.
///
/// Home, Route Preview and Active Navigation all render one edge-to-edge
/// [MapWidget] straight through the status bar, so the only thing that makes
/// the clock, signal, wifi and battery icons readable is their brightness:
/// dark icons over the light (day) map, light icons over the dark (night) map.
///
/// The bar itself stays fully transparent (no scrim, no solid colour), so
/// nothing is painted over the icons and the map keeps the top of the screen.
/// Kept in one place so the three screens cannot drift apart.
SystemUiOverlayStyle naviSystemUiOverlayStyle(bool isDark) {
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    // iOS derives the icon colour from this instead of the field above.
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
  );
}
