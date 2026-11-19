import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/models/app_settings.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/widgets/home/nearby_stages_sheet.dart';
import 'package:navi_app/widgets/nearby_stages_list.dart';
import 'package:navi_app/widgets/route_badge.dart';

Widget _wrap(Widget sheet) => MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(
          child: Stack(
            children: [Positioned.fill(child: sheet)],
          ),
        ),
      ),
    );

NearbyStagesSheet _sheet({
  required NearbyStagesStatus status,
  List<NearbyStageEntry> entries = const [],
  required ValueChanged<StageModel> onStageTap,
  VoidCallback? onEnableLocation,
}) {
  return NearbyStagesSheet(
    initialSize: 0.4,
    minSize: 0.4,
    maxSize: 0.85,
    status: status,
    entries: entries,
    distanceUnit: DistanceUnit.km,
    onStageTap: onStageTap,
    onSizeChanged: (_) {},
    onEnableLocation: onEnableLocation ?? () {},
    onOpenSettings: () {},
    onRetry: () {},
  );
}

void main() {
  setUp(() {});

  final near = StageModel(
    id: 's1',
    name: 'Kilimani',
    lat: -1.29,
    lng: 36.78,
    corridor: 'Argwings Kodhek',
    routes: ['34', '125', '8', '45'],
  );
  final farther = StageModel(
    id: 's2',
    name: 'Yaya Centre',
    lat: -1.2925,
    lng: 36.7865,
    corridor: 'Argwings Kodhek',
    routes: ['46'],
  );

  group('NearbyStagesSheet', () {
    testWidgets('lists real stages, shared distance text and route badges',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      StageModel? tapped;
      await tester.pumpWidget(_wrap(_sheet(
        status: NearbyStagesStatus.ready,
        entries: [
          NearbyStageEntry(stage: near, distanceMeters: 732),
          NearbyStageEntry(stage: farther, distanceMeters: 1234),
        ],
        onStageTap: (stage) => tapped = stage,
      )));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Nearby Stages'), findsOneWidget);
      expect(find.text('See all →'), findsOneWidget);
      expect(find.text('Kilimani'), findsOneWidget);
      expect(find.text('732 m away · Nearest'), findsOneWidget);
      expect(find.text('1.2 km away'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      // Two badges for the first stage, one for the second.
      expect(find.byType(RouteBadge), findsNWidgets(3));
      // The mockup's sample distance/name is never used.
      expect(find.textContaining('Makadara'), findsNothing);

      await tester.tap(find.text('Kilimani'));
      expect(tapped, near);
    });

    testWidgets('locating state shows the message and three skeleton rows',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(_sheet(
        status: NearbyStagesStatus.locating,
        onStageTap: (_) {},
      )));
      await tester.pump();

      expect(find.text('Finding stages near you...'), findsOneWidget);
      expect(find.byType(RouteBadge), findsNothing);
    });

    testWidgets('denied state offers Enable location', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var enable = 0;
      await tester.pumpWidget(_wrap(_sheet(
        status: NearbyStagesStatus.denied,
        onStageTap: (_) {},
        onEnableLocation: () => enable++,
      )));
      await tester.pump();

      expect(
          find.text('Turn on location to see nearby stages'), findsOneWidget);
      await tester.tap(find.text('Enable location'));
      expect(enable, 1);
    });

    testWidgets('empty state says no stages are nearby yet', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(_sheet(
        status: NearbyStagesStatus.empty,
        onStageTap: (_) {},
      )));
      await tester.pump();

      expect(find.text('No stages nearby yet'), findsOneWidget);
    });
  });
}
