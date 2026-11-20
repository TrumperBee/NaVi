import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import 'package:navi_app/design/navi_marker_theme.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/fare_estimate.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/screens/route_preview_screen.dart';
import 'package:navi_app/services/stage_route_summary.dart';
import 'package:navi_app/widgets/pre_trip_card.dart' show PreTripExtras;
import 'package:navi_app/widgets/route_preview/route_preview_data.dart';

const _origin = LatLng(-1.2800, 36.8100);
const _boarding = LatLng(-1.2833, 36.8167);
const _alight = LatLng(-1.2900, 36.8300);
const _destination = LatLng(-1.2950, 36.8400);

StageModel _stage(String id, String name) => StageModel(
      id: id,
      name: name,
      lat: -1.2850,
      lng: 36.8200,
      corridor: 'Jogoo Road',
      routes: const ['34', '58'],
    );

RouteSegment _walk(String label, LatLng from, LatLng to) => RouteSegment.walk(
      label: label,
      coordinates: [from, to],
      startPoint: from,
      endPoint: to,
    );

ActiveJourney _rideJourney() {
  final ride = RouteSegment.matatu(
    label: 'Matatu 34 to Utawala',
    coordinates: const [_boarding, _alight],
    routeNumber: '34',
    startPoint: _boarding,
    endPoint: _alight,
    fromStageId: 'makadara',
    toStageId: 'utawala',
  ).copyWith(
    fareEstimate: FareEstimate.matatu(
      amountKsh: 50,
      tier: FareTier.medium,
      timeOfDay: TimeOfDay.offPeak,
    ),
  );

  return ActiveJourney(segments: [
    _walk('Walk to Makadara Stage', _origin, _boarding),
    ride,
    _walk('Walk to Utawala', _alight, _destination),
  ]);
}

ActiveJourney _walkJourney() => ActiveJourney(segments: [
      _walk('Walk to Makadara Stage', _origin, _boarding),
    ]);

PathOption _option({
  required List<String> routeNumbers,
  required int totalTime,
  required double totalFare,
  required String description,
}) {
  final makadara = _stage('makadara', 'Makadara Stage');
  final utawala = _stage('utawala', 'Utawala');
  return PathOption(
    path: [
      Node(
        id: 'user',
        name: 'Current location',
        lat: _origin.latitude,
        lng: _origin.longitude,
        type: 'place',
      ),
      makadara,
      utawala,
    ],
    edges: const [],
    totalDistance: 3200,
    totalTime: totalTime,
    totalFare: totalFare,
    transferCount: 0,
    routeNumbers: routeNumbers,
    description: description,
  );
}

const _extras = PreTripExtras(
  headwayText: 'Matatus come every 5-15 min',
  headsigns: {1: 'Utawala'},
  stopCounts: {1: 12},
);

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(body: child),
    );

RoutePreviewScreen _screen({
  required RoutePreviewMode mode,
  required ActiveJourney journey,
  required PathOption selectedPath,
  List<PathOption> pathOptions = const [],
  StageModel? stage,
  List<StageRouteSummary> stageRoutes = const [],
  PreTripExtras? extras = _extras,
  VoidCallback? onStartJourney,
  ValueChanged<PathOption>? onSelectOption,
}) {
  return RoutePreviewScreen(
    map: const ColoredBox(color: Color(0xFFEFEFEF)),
    mode: mode,
    journey: journey,
    selectedPath: selectedPath,
    pathOptions: pathOptions,
    stages: [
      _stage('makadara', 'Makadara Stage'),
      _stage('utawala', 'Utawala')
    ],
    extras: extras,
    stage: stage,
    stageRoutes: stageRoutes,
    destinationLabel: stage?.name ?? 'Utawala',
    onBack: () {},
    onStartJourney: onStartJourney ?? () {},
    onSelectOption: onSelectOption ?? (_) {},
    onRetry: () {},
    onFitRoute: () {},
  );
}

void main() {
  testWidgets('destination mode: real route data, no Other Routes, CTA visible',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var started = false;
    final option = _option(
      routeNumbers: const ['34'],
      totalTime: 1740,
      totalFare: 60,
      description: 'Makadara Stage → Utawala',
    );

    await tester.pumpWidget(_wrap(_screen(
      mode: RoutePreviewMode.destination,
      journey: _rideJourney(),
      selectedPath: option,
      pathOptions: [option],
      onStartJourney: () => started = true,
    )));
    await tester.pump();

    expect(tester.takeException(), isNull);

    // Chrome + sheet copy.
    expect(find.text('Route Details'), findsOneWidget);
    expect(find.text('Route 34'), findsOneWidget);
    expect(find.text('Makadara Stage → Utawala'), findsOneWidget);
    expect(find.text('via Jogoo Road'), findsOneWidget);
    expect(find.text('(12 stops)'), findsOneWidget);
    expect(find.text('Board at Makadara Stage'), findsOneWidget);
    expect(find.text('1 transfer'), findsNothing);
    expect(find.textContaining('Makadara'), findsWidgets);

    // Only one route: the alternatives section never appears.
    expect(find.text('Other Routes'), findsNothing);
    expect(find.text('See all →'), findsNothing);
    expect(find.text('Routes from this stage'), findsNothing);

    // The CTA is fully on screen on a 360×640 phone.
    final cta = find.text('Start Journey');
    expect(cta, findsOneWidget);
    expect(tester.getBottomLeft(cta).dy, lessThanOrEqualTo(640));

    await tester.tap(cta);
    await tester.pump();
    expect(started, isTrue);
  });

  testWidgets('destination mode: an approximate walk shows the small note',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final option = _option(
      routeNumbers: const ['34'],
      totalTime: 1740,
      totalFare: 60,
      description: 'Makadara Stage  Utawala',
    );
    final journey = ActiveJourney(segments: [
      RouteSegment.walk(
        label: 'Walk to Makadara Stage',
        coordinates: const [_origin, _boarding],
        startPoint: _origin,
        endPoint: _boarding,
        approximate: true,
      ),
      RouteSegment.matatu(
        label: 'Ride Route 34 to Utawala',
        coordinates: const [_boarding, _alight],
        routeNumber: '34',
        startPoint: _boarding,
        endPoint: _alight,
        fromStageId: 'makadara',
        toStageId: 'utawala',
      ),
    ]);

    await tester.pumpWidget(_wrap(_screen(
      mode: RoutePreviewMode.destination,
      journey: journey,
      selectedPath: option,
      pathOptions: [option],
    )));
    await tester.pump();

    expect(find.text('Approximate route'), findsOneWidget);
  });

  testWidgets('destination mode: alternative routes switch the preview',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    PathOption? selected;
    final primary = _option(
      routeNumbers: const ['34'],
      totalTime: 1740,
      totalFare: 60,
      description: 'Makadara Stage → Utawala',
    );
    final alternative = _option(
      routeNumbers: const ['58'],
      totalTime: 2160,
      totalFare: 70,
      description: 'Makadara Stage → Utawala via 58',
    );

    await tester.pumpWidget(_wrap(_screen(
      mode: RoutePreviewMode.destination,
      journey: _rideJourney(),
      selectedPath: primary,
      pathOptions: [primary, alternative],
      onSelectOption: (option) => selected = option,
    )));
    await tester.pump();

    expect(tester.takeException(), isNull);

    // The CTA is fully on screen on a 412×915 phone too.
    final cta = find.text('Start Journey');
    expect(cta, findsOneWidget);
    expect(tester.getBottomLeft(cta).dy, lessThanOrEqualTo(915));

    // Expand the sheet to its 90% maximum; on a 412×915 screen the whole
    // alternatives section then fits without further scrolling.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Other Routes'), findsOneWidget);
    expect(find.text('See all →'), findsOneWidget);
    expect(find.text('Route 58'), findsOneWidget);
    expect(find.text('≈ 36 min'), findsOneWidget);
    expect(find.text('KSh 70'), findsOneWidget);

    await tester.tap(find.text('Route 58'));
    await tester.pump();
    expect(identical(selected, alternative), isTrue);
  });

  testWidgets('stage mode: walk to the stage and list its routes',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final stage = _stage('makadara', 'Makadara Stage');
    final journey = _walkJourney();
    final walkMinutes = (journey.walkDuration.inSeconds / 60).round();
    final banner =
        'About $walkMinutes min to reach this stage. '
        'Matatus from here are listed below.';
    final option = _option(
      routeNumbers: const ['walk'],
      totalTime: 780,
      totalFare: 0,
      description: 'Walk to Makadara Stage',
    );

    await tester.pumpWidget(_wrap(_screen(
      mode: RoutePreviewMode.stage,
      journey: journey,
      selectedPath: option,
      stage: stage,
      stageRoutes: const [
        StageRouteSummary(
          routeNumber: '58',
          headsign: 'Buruburu',
          headwayText: 'A matatu comes every 5-15 min right now',
        ),
        StageRouteSummary(
          routeNumber: '34',
          headsign: 'Utawala',
          headwayText: StageRouteSummaries.noFrequencyText,
        ),
      ],
    )));
    await tester.pump();

    expect(tester.takeException(), isNull);

    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('Walk to Makadara Stage'), findsWidgets);
    expect(find.text(banner), findsOneWidget);
    // The full two-line banner must not overflow on a 360dp screen.
    expect(tester.takeException(), isNull);
    expect(find.text('Start Journey'), findsOneWidget);

    // No ride metric and no destination-mode alternatives.
    expect(find.text('Other Routes'), findsNothing);
    expect(find.textContaining('Board at'), findsNothing);
    expect(find.textContaining('stops'), findsNothing);

    // The upward drag expands the draggable sheet; jump the list itself to the
    // end so the assertion checks the scroll padding, not the sheet gesture.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    final scrollState =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('Routes from this stage'), findsOneWidget);
    expect(find.text('Route 58'), findsOneWidget);
    expect(find.text('→ Buruburu'), findsOneWidget);
    expect(
        find.text('A matatu comes every 5-15 min right now'), findsOneWidget);
    expect(find.text(StageRouteSummaries.noFrequencyText), findsOneWidget);

    // The last card still has the full system inset + 24dp scroll padding
    // below it, so neither the rounded sheet edge nor the gesture bar clips it.
    final lastCard = find.byKey(const Key('stageRouteCard_34'));
    expect(lastCard, findsOneWidget);
    expect(
      tester.getBottomRight(lastCard).dy,
      lessThanOrEqualTo(640 - 24 + 1),
    );
  });

  testWidgets('route preview publishes ambient brightness to marker chips',
      (tester) async {
    addTearDown(() => NaviMarkerTheme.isDark = false);
    final option = _option(
      routeNumbers: const ['walk'],
      totalTime: 780,
      totalFare: 0,
      description: 'Walk to Makadara Stage',
    );

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: Scaffold(
        body: _screen(
          mode: RoutePreviewMode.stage,
          journey: _walkJourney(),
          selectedPath: option,
          stage: _stage('makadara', 'Makadara Stage'),
        ),
      ),
    ));
    await tester.pump();

    expect(NaviMarkerTheme.isDark, isTrue);
    expect(NaviMarkerTheme.chipBackground, const Color(0xFF2B3037));
  });
}
