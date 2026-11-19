import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';
import 'package:navi_app/widgets/quick_go_row.dart';

/// The two pill lines joined as rendered: "Title · address line".
String _pillText(WidgetTester tester, int chipIndex) {
  final chip = find.byType(InkWell).at(chipIndex);
  final lines = tester
      .widgetList<Text>(
        find.descendant(of: chip, matching: find.byType(Text)),
      )
      .map((t) => t.data ?? '')
      .where((d) => d.isNotEmpty);
  return lines.join(' · ');
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // Both places reverse-geocoded to the exact same label text, saved at
  // different coordinates — the failure case the pill layout must solve.
  const home = SavedDestination(
    id: 'home',
    label: 'Nairobi',
    latitude: -1.2741,
    longitude: 36.8084,
    type: SavedDestinationType.home,
  );
  const campus = SavedDestination(
    id: 'campus',
    label: 'Nairobi',
    latitude: -1.2864,
    longitude: 36.8171,
    type: SavedDestinationType.campus,
  );

  group('QuickGoRow saved-place pills', () {
    testWidgets(
        'two saved places with identical reverse-geocode text still render '
        'as clearly different pills', (tester) async {
      SavedDestination? tapped;
      SavedDestination? edited;
      await tester.pumpWidget(_wrap(QuickGoRow(
        destinations: const [home, campus],
        onTap: (d) => tapped = d,
        onEdit: (d) => edited = d,
      )));

      final homePill = _pillText(tester, 0);
      final campusPill = _pillText(tester, 1);

      expect(homePill, 'Home · -1.274, 36.808');
      expect(campusPill, 'Campus · -1.286, 36.817');
      expect(homePill, isNot(equals(campusPill)));
      // The city label never shows as a pill's own line.
      expect(find.text('Nairobi'), findsNothing);

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(tapped, home);

      await tester.longPress(find.byType(InkWell).last);
      await tester.pump();
      expect(edited, campus);
    });

    testWidgets('pill shows the street when the reverse geocode succeeded',
        (tester) async {
      const street = SavedDestination(
        id: 'work',
        label: 'Chiromo Road, Nairobi, Kenya',
        latitude: -1.2741,
        longitude: 36.8084,
        type: SavedDestinationType.work,
      );
      await tester.pumpWidget(_wrap(QuickGoRow(
        destinations: const [street],
        onTap: (_) {},
      )));

      expect(_pillText(tester, 0), 'Work · Chiromo Road');
      expect(find.text('Nairobi'), findsNothing);
    });

    testWidgets('failed geocode falls back to coordinates, never blank',
        (tester) async {
      // Reverse geocode failed: the dialog stored the slot name itself.
      const failed = SavedDestination(
        id: 'home',
        label: 'Home',
        latitude: -1.2741,
        longitude: 36.8084,
        type: SavedDestinationType.home,
      );
      await tester.pumpWidget(_wrap(QuickGoRow(
        destinations: const [failed],
        onTap: (_) {},
      )));

      expect(_pillText(tester, 0), 'Home · -1.274, 36.808');
    });
  });
}
