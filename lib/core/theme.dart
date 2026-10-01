import 'package:flutter/material.dart';

import 'constants.dart';
import '../design/navi_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppConstants.nairobiGreen,
      scaffoldBackgroundColor: NaviColors.canvasLight,
      canvasColor: NaviColors.canvasLight,
      cardColor: NaviColors.surfaceLight,
      dividerColor: NaviColors.divider,
      dividerTheme: const DividerThemeData(color: NaviColors.divider),
      dialogTheme: const DialogThemeData(
        backgroundColor: NaviColors.surfaceLight,
      ),
      colorScheme: const ColorScheme.light(
        primary: AppConstants.nairobiGreen,
        secondary: AppConstants.nairobiGreen,
        surface: NaviColors.surfaceLight,
        background: NaviColors.canvasLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.nairobiGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppConstants.nairobiGreen,
      scaffoldBackgroundColor: NaviColors.canvasDark,
      canvasColor: NaviColors.canvasDark,
      cardColor: NaviColors.surfaceDark,
      dividerColor: NaviColors.dividerDark,
      dividerTheme: const DividerThemeData(color: NaviColors.dividerDark),
      dialogTheme: const DialogThemeData(
        backgroundColor: NaviColors.surfaceDark,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppConstants.nairobiGreen,
        secondary: AppConstants.nairobiGreen,
        surface: NaviColors.surfaceDark,
        background: NaviColors.canvasDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.nairobiGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: NaviColors.surfaceDark,
      ),
    );
  }

  static ThemeData getTheme(bool isDark) {
    return isDark ? darkTheme : lightTheme;
  }
}