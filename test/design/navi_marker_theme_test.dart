import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/design/navi_colors.dart';
import 'package:navi_app/design/navi_marker_theme.dart';

void main() {
  tearDown(() => NaviMarkerTheme.isDark = false);

  test('preview pins and chips match the Route Preview spec', () {
    expect(NaviMarkerTheme.pinHeight, 32);
    expect(NaviMarkerTheme.pinWidth, 22);
    expect(NaviMarkerTheme.chipFontSize, 13);
    expect(NaviMarkerTheme.chipMaxWidth, 180);
    expect(NaviMarkerTheme.chipTailHeight, greaterThan(0));
  });

  test('dark secondary text meets the lifted #AEB5BF token', () {
    expect(NaviColors.textSecondaryDark, const Color(0xFFAEB5BF));
    expect(NaviColors.textSecondary(true), NaviColors.textSecondaryDark);
  });

  test('light preview label chip is white with dark text', () {
    NaviMarkerTheme.isDark = false;

    expect(NaviMarkerTheme.chipBackground, Colors.white);
    expect(NaviMarkerTheme.chipText, NaviColors.textPrimaryLight);
  });

  test('dark preview label chip is dark grey with light text', () {
    NaviMarkerTheme.isDark = true;

    expect(NaviMarkerTheme.chipBackground, const Color(0xFF2B3037));
    expect(NaviMarkerTheme.chipText, NaviColors.textPrimaryDark);
  });
}
