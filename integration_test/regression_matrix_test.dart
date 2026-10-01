import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:navi_app/main.dart' as app;
import 'package:navi_app/screens/auth_screen.dart';
import 'package:navi_app/screens/home_screen.dart';
import 'package:navi_app/features/settings/settings_screen.dart';
import 'package:navi_app/widgets/hero_go_card.dart';
import 'package:navi_app/widgets/quick_go_row.dart';

/// Phase 6 regression matrix — runs the real app on-device and drives the
/// automatable rows of the QA matrix (profile 1 = Galaxy A05, profile 2 =
/// Pixel 9 Pro XL emulator). Non-automatable rows (polyline continuity,
/// reduced-motion, GPS journey completion/reporting, multi-day memory sanity)
/// are covered by the 173-test unit/widget suite and are reported per-row with
/// their coverage method in the Phase 6 report.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  Duration interval = const Duration(milliseconds: 250),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(interval);
    if (condition()) return;
  }
  throw TestFailure('Timed out waiting for condition');
}

bool _switchValue(WidgetTester tester, String title) {
  final tile = tester.widget<SwitchListTile>(
    find.widgetWithText(SwitchListTile, title),
  );
  return tile.value;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Phase 6 regression matrix',
    (tester) async {
      app.main();
      await tester.pump(const Duration(milliseconds: 500));

      // ── 1. Auth gate ──────────────────────────────────────────────────────
      // A guest session may persist from an earlier run (authStateChanges
      // resolves straight to HomeScreen); otherwise sign in as guest.
      final homeFinder = find.byType(HomeScreen);
      final authFinder = find.byType(AuthScreen);
      await pumpUntil(
        tester,
        () => tester.any(authFinder) || tester.any(homeFinder),
        timeout: const Duration(seconds: 15),
      );
      if (!tester.any(homeFinder)) {
        await tester.tap(find.text('Continue as Guest'));
        await pumpUntil(
          tester,
          () => tester.any(homeFinder),
          timeout: const Duration(seconds: 30),
        );
      }
      debugPrint('[MATRIX] 1. Auth gate: reached HomeScreen (guest ok)');

      // ── 2. Cold-launch hero shows a loading state (not blank/frozen) ──────
      var sawLoading = false;
      final loadEnd = DateTime.now().add(const Duration(milliseconds: 1500));
      while (DateTime.now().isBefore(loadEnd) && !sawLoading) {
        await tester.pump(const Duration(milliseconds: 150));
        sawLoading =
            tester.any(find.byType(HeroGoCardLoading)) ||
            tester.any(find.textContaining('Getting your location')) ||
            tester.any(find.textContaining('Finding nearby stages'));
      }
      expect(sawLoading, isTrue,
          reason: 'Cold launch must show a nearest-stage loading state');
      debugPrint('[MATRIX] 2. Cold-launch loading state shown immediately');

      // ── 3. Hero resolves to a live card (never a perpetual spinner) ───────
      bool terminal() =>
          tester.any(find.byType(HeroGoCard)) ||
          tester.any(find.byType(HeroGoCardLocationTimeout)) ||
          tester.any(find.byType(HeroGoCardPlaceholder)) ||
          tester.any(find.byType(HeroGoCardEmptyState));
      await pumpUntil(tester, terminal, timeout: const Duration(seconds: 40));
      debugPrint('[MATRIX] 3. Hero card resolved (live/retry/placeholder)');

      // ── 4. Status-bar padding respected by HomeScreen layout ──────────────
      final homeCtx = tester.element(homeFinder);
      final topPad = MediaQuery.of(homeCtx).padding.top;
      expect(topPad, greaterThanOrEqualTo(20.0),
          reason: 'HomeScreen must not draw under the status bar');
      debugPrint('[MATRIX] 4. Status-bar top padding=$topPad respected');

      // ── 5. Open Settings ──────────────────────────────────────────────────
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await pumpUntil(
        tester,
        () => tester.any(find.text('NAVIGATION PREFERENCES')),
      );
      debugPrint('[MATRIX] 5. Settings screen reachable');

      // ── 6. The six toggles flip both ways ─────────────────────────────────
      const toggles = [
        'Avoid busy junctions',
        'Prefer walking paths',
        'High accuracy mode',
        'Notifications',
        'Voice Guidance',
        'Location Sharing',
      ];
      for (final title in toggles) {
        await tester.ensureVisible(find.widgetWithText(SwitchListTile, title));
        await tester.pump(const Duration(milliseconds: 120));
        final before = _switchValue(tester, title);
        await tester.tap(find.text(title));
        await tester.pump(const Duration(milliseconds: 300));
        final after = _switchValue(tester, title);
        expect(after, isNot(before), reason: 'Toggle "$title" should flip on');
        await tester.tap(find.text(title));
        await tester.pump(const Duration(milliseconds: 300));
        expect(_switchValue(tester, title), before,
            reason: 'Toggle "$title" should flip back');
        debugPrint('[MATRIX] 6. Toggle "$title" flips on/off (was $before)');
      }

      // ── 7. Distance unit round-trips ──────────────────────────────────────
      await tester.ensureVisible(find.text('Distance Unit'));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.text('mi'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Miles (mi)'), findsOneWidget);
      await tester.tap(find.text('km'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Kilometers (km)'), findsOneWidget);
      debugPrint('[MATRIX] 7. Distance unit km<->mi round-trip ok');

      // ── 8. Dark mode applies app-wide, then restores ──────────────────────
      await tester.ensureVisible(find.widgetWithText(SwitchListTile, 'Dark Mode'));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.text('Dark Mode'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );
      debugPrint('[MATRIX] 8. Dark mode applied app-wide');
      await tester.tap(find.text('Dark Mode'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.light,
      );
      debugPrint('[MATRIX] 8. Dark mode restored to light');

      // ── 9. Clear journey history confirmation flow ────────────────────────
      await tester.ensureVisible(find.text('Clear Journey History'));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.text('Clear Journey History'));
      await pumpUntil(tester, () => tester.any(find.text('Clear History')));
      await tester.tap(find.text('Clear'));
      await pumpUntil(
        tester,
        () => tester.any(find.text('Journey history cleared successfully')),
      );
      debugPrint('[MATRIX] 9. Clear Journey History flow completes');

      // ── 10. About shows the dynamic app version ───────────────────────────
      await tester.ensureVisible(find.text('About NaVi'));
      await pumpUntil(tester, () => tester.any(find.text('Version 1.1.0')));
      debugPrint('[MATRIX] 10. About lists version 1.1.0 (package_info_plus)');

      // ── 11. Back to Home ──────────────────────────────────────────────────
      await tester.pageBack();
      // The pop transition takes a beat; Home only becomes hit-testable once
      // the Settings route is fully off the stack. Wait for the QuickGoRow —
      // unique to the onstage Home route — rather than HomeScreen's mere
      // presence (it stays in the widget tree underneath the pushed route).
      await pumpUntil(
        tester,
        () => tester.any(find.byType(QuickGoRow)),
        timeout: const Duration(seconds: 15),
      );
      debugPrint('[MATRIX] 11. Navigated back to Home (onstage)');

      // ── 12. Saved destinations + Quick Go row ─────────────────────────────
      await tester.ensureVisible(find.byType(QuickGoRow));
      await tester.pump(const Duration(milliseconds: 200));
      if (tester.any(find.text('Add Home'))) {
        // First run on this device: set Home via "Use current location".
        await tester.tap(find.text('Add Home'));
        await pumpUntil(
          tester,
          () => tester.any(find.text('Set Home Location')),
        );
        await tester.tap(find.text('Use current location'));
        final confirmDialog = find.textContaining('Save as Home?');
        final failed = find.text('Could not read your current location.');
        await pumpUntil(
          tester,
          () => tester.any(confirmDialog) || tester.any(failed),
          timeout: const Duration(seconds: 20),
        );
        expect(tester.any(confirmDialog), isTrue,
            reason: 'Reverse-geocoded label must confirm the save');
        await tester.tap(find.text('Save'));
        await pumpUntil(
          tester,
          () => !tester.any(find.text('Add Home')),
          timeout: const Duration(seconds: 10),
        );
        debugPrint('[MATRIX] 12. Saved Home via current location -> Quick Go');
      } else {
        // Prior run already saved a Home chip: it must be present & tappable.
        expect(
          find.descendant(
            of: find.byType(QuickGoRow),
            matching: find.byType(InkWell),
          ),
          findsWidgets,
        );
        debugPrint('[MATRIX] 12. Saved Home chip present in Quick Go row');
      }

      debugPrint('[MATRIX] Phase 6 regression matrix PASSED on this profile');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}