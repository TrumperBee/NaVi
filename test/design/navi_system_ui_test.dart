import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/design/navi_system_ui.dart';

void main() {
  group('naviSystemUiOverlayStyle', () {
    test('light mode draws dark status-bar icons over the day map', () {
      final style = naviSystemUiOverlayStyle(false);

      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
    });

    test('dark mode draws light status-bar icons over the night map', () {
      final style = naviSystemUiOverlayStyle(true);

      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
    });

    test('the status bar is never painted over with a colour', () {
      expect(naviSystemUiOverlayStyle(true).statusBarColor, Colors.transparent);
      expect(
        naviSystemUiOverlayStyle(false).statusBarColor,
        Colors.transparent,
      );
    });
  });
}
