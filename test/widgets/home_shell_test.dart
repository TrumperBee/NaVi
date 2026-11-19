import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/design/navi_colors.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';
import 'package:navi_app/widgets/home/home_bottom_nav.dart';
import 'package:navi_app/widgets/home/home_header_panel.dart';
import 'package:navi_app/widgets/home/home_map_controls.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

const _home = SavedDestination(
  id: 'home',
  label: 'Chiromo Road, Nairobi, Kenya',
  latitude: -1.2741,
  longitude: 36.8084,
  type: SavedDestinationType.home,
);

void main() {
  setUp(() {
    // 360dp-wide phone, the narrow layout this screen must survive.
  });

  group('HomeHeaderPanel', () {
    testWidgets('shows only real saved data and no sample values',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(HomeHeaderPanel(
        userInitial: 'V',
        onAvatarTap: () {},
        onSearchTap: () {},
        onLocateTap: () {},
        onSeeAllQuickGo: () {},
        destinations: const [_home],
        onDestinationTap: (_) {},
        onDestinationLongPress: (_) {},
        onSetDestination: (_) {},
        onSavedTap: () {},
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('NaVi'), findsOneWidget);
      expect(find.text('Navigate Nairobi'), findsOneWidget);
      expect(find.text('V'), findsOneWidget);
      expect(find.text(HomeHeaderPanel.searchHint), findsOneWidget);
      expect(find.text('Quick Go'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Campus'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);

      // Real address for the saved slot, "Tap to set" for the empty ones.
      expect(find.text('Chiromo Road'), findsOneWidget);
      expect(find.text('Tap to set'), findsNWidgets(2));
      expect(find.text('1 saved'), findsOneWidget);

      // The mockup's sample stage/distance never appears.
      expect(find.textContaining('Makadara'), findsNothing);
      expect(find.textContaining('732'), findsNothing);
    });

    testWidgets('empty Home tile sets the place, filled tile routes there',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SavedDestinationType? setKind;
      SavedDestination? routed;
      await tester.pumpWidget(_wrap(HomeHeaderPanel(
        userInitial: 'N',
        onAvatarTap: () {},
        onSearchTap: () {},
        onLocateTap: () {},
        onSeeAllQuickGo: () {},
        destinations: const [_home],
        onDestinationTap: (d) => routed = d,
        onDestinationLongPress: (_) {},
        onSetDestination: (kind) => setKind = kind,
        onSavedTap: () {},
      )));

      await tester.tap(find.text('Work'));
      expect(setKind, SavedDestinationType.work);
      expect(routed, isNull);

      await tester.tap(find.text('Home').first);
      expect(routed, _home);
    });

    testWidgets('search, locate, avatar and See all are wired', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var search = 0;
      var locate = 0;
      var avatar = 0;
      var seeAll = 0;
      await tester.pumpWidget(_wrap(HomeHeaderPanel(
        userInitial: 'N',
        onAvatarTap: () => avatar++,
        onSearchTap: () => search++,
        onLocateTap: () => locate++,
        onSeeAllQuickGo: () => seeAll++,
        destinations: const [],
        onDestinationTap: (_) {},
        onDestinationLongPress: (_) {},
        onSetDestination: (_) {},
        onSavedTap: () {},
      )));

      await tester.tap(find.text(HomeHeaderPanel.searchHint));
      await tester.tap(find.byIcon(Icons.my_location));
      await tester.tap(find.text('N'));
      await tester.tap(find.text('See all →'));
      expect(search, 1);
      expect(locate, 1);
      expect(avatar, 1);
      expect(seeAll, 1);
    });

    testWidgets('40dp circles expose 48dp tap targets', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(HomeHeaderPanel(
        userInitial: 'N',
        onAvatarTap: () {},
        onSearchTap: () {},
        onLocateTap: () {},
        onSeeAllQuickGo: () {},
        destinations: const [],
        onDestinationTap: (_) {},
        onDestinationLongPress: (_) {},
        onSetDestination: (_) {},
        onSavedTap: () {},
      )));

      final avatarInk = find.ancestor(
        of: find.text('N'),
        matching: find.byType(InkWell),
      );
      final locateInk = find.ancestor(
        of: find.byIcon(Icons.my_location),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(avatarInk.first).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(avatarInk.first).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(locateInk.first).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(locateInk.first).height, greaterThanOrEqualTo(48));
    });
  });

  group('HomeMapControls', () {
    testWidgets('layers / zoom / re-center callbacks fire', (tester) async {
      var layers = 0;
      var zoomIn = 0;
      var zoomOut = 0;
      var recenter = 0;
      await tester.pumpWidget(_wrap(HomeMapControls(
        satellite: false,
        onToggleLayers: () => layers++,
        onZoomIn: () => zoomIn++,
        onZoomOut: () => zoomOut++,
        onRecenter: () => recenter++,
      )));

      await tester.tap(find.byIcon(Icons.layers_outlined));
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.remove));
      await tester.tap(find.byIcon(Icons.navigation));

      expect(layers, 1);
      expect(zoomIn, 1);
      expect(zoomOut, 1);
      expect(recenter, 1);
      expect(find.byIcon(Icons.navigation), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.navigation)).color,
        NaviColors.signalBlue,
      );
    });

    testWidgets('satellite state swaps the layers icon', (tester) async {
      await tester.pumpWidget(_wrap(HomeMapControls(
        satellite: true,
        onToggleLayers: () {},
        onZoomIn: () {},
        onZoomOut: () {},
        onRecenter: () {},
      )));
      expect(find.byIcon(Icons.satellite_alt), findsOneWidget);
      expect(find.byIcon(Icons.layers_outlined), findsNothing);
    });
  });

  group('HomeBottomNav', () {
    testWidgets('has Home / History / Settings and a 3dp emerald underline',
        (tester) async {
      int? selected;
      await tester.pumpWidget(_wrap(HomeBottomNav(
        selectedIndex: 0,
        onSelected: (i) => selected = i,
      )));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      final underline = find
          .descendant(
            of: find.byType(HomeBottomNav),
            matching: find.byType(AnimatedContainer),
          )
          .first;
      expect(tester.getSize(underline).height, 3);

      await tester.tap(find.text('History'));
      expect(selected, 1);
      await tester.tap(find.text('Settings'));
      expect(selected, 2);
    });
  });
}
