import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/fare_estimate.dart' as fare;
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/services/distance_calculator.dart';
import 'package:navi_app/utils/distance_formatter.dart';
import 'package:navi_app/widgets/pre_trip_card.dart';

const _origin = LatLng(-1.2800, 36.8100);
const _boarding = LatLng(-1.2833, 36.8167);
const _alight = LatLng(-1.2900, 36.8300);
const _destination = LatLng(-1.2950, 36.8400);

StageModel _stage(String id, String name) => StageModel(
      id: id,
      name: name,
      lat: -1.28,
      lng: 36.81,
      corridor: 'Test Corridor',
      routes: const ['58'],
    );

RouteSegment _walkSegment(String label, LatLng from, LatLng to) =>
    RouteSegment.walk(
      label: label,
      coordinates: [from, to],
      startPoint: from,
      endPoint: to,
    );

RouteSegment _rideSegment() => RouteSegment(
      mode: SegmentMode.matatu,
      label: 'Ride Route 58 to Buruburu',
      coordinates: const [_boarding, _alight],
      routeNumber: '58',
      startPoint: _boarding,
      endPoint: _alight,
      distanceMeters: DistanceCalculator.distanceMeters(_boarding, _alight),
      estimatedDuration: Duration(
        seconds: (DistanceCalculator.distanceMeters(_boarding, _alight) /
                (20000 / 3600))
            .round(),
      ),
      fareEstimate: fare.FareEstimate.matatu(
        amountKsh: 25,
        tier: fare.FareTier.short,
        timeOfDay: fare.TimeOfDay.offPeak,
      ),
      fromStageId: 'jerusalem',
      toStageId: 'buruburu',
    );

ActiveJourney _journey() => ActiveJourney(segments: [
      _walkSegment('Walk to Jerusalem Stage', _origin, _boarding),
      _rideSegment(),
      _walkSegment('Walk to Kiosk', _alight, _destination),
    ]);

List<StageModel> _stages() => [
      _stage('jerusalem', 'Jerusalem Stage'),
      _stage('buruburu', 'Buruburu'),
    ];

PathOption _option(String route, {int seconds = 1200, double fareKsh = 25}) =>
    PathOption(
      path: <Node>[],
      edges: <Edge>[],
      totalDistance: 1000,
      totalTime: seconds,
      totalFare: fareKsh,
      transferCount: 0,
      routeNumbers: [route],
      description: 'route $route',
    );

int _minutes(double meters, double speedMps) {
  final seconds = (meters / speedMps).round();
  final minutes = (seconds / 60).round();
  return minutes < 1 ? 1 : minutes;
}

String _timeLabel(Duration d) {
  final rounded = d.inMinutes + (d.inSeconds % 60 >= 30 ? 1 : 0);
  if (rounded < 60) return '$rounded min';
  final h = rounded ~/ 60;
  final m = rounded % 60;
  return m == 0 ? '$h hr' : '$h hr $m min';
}

PreTripExtrasLoader _fakeExtras() => (journey, stages) async =>
    const PreTripExtras(
      headwayText: 'Matatus come every 5-15 min',
      headsigns: {1: 'Buruburu'},
      stopCounts: {1: 8},
    );

Future<void> _useTestSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _app(Widget child, {bool disableAnimations = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 1400),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(width: 400, child: child),
          ),
        ),
      ),
    );

PreTripCard _card({
  bool loading = false,
  bool error = false,
  ActiveJourney? journey,
  List<PathOption>? pathOptions,
  PathOption? selectedPath,
  PreTripExtrasLoader? extrasLoader,
  VoidCallback? onStartJourney,
  ValueChanged<PathOption>? onSelectOption,
  VoidCallback? onRetry,
}) =>
    PreTripCard(
      loading: loading,
      error: error,
      journey: journey,
      stages: _stages(),
      pathOptions: pathOptions ?? [_option('58')],
      selectedPath: selectedPath,
      onSelectOption: onSelectOption ?? (_) {},
      onStartJourney: onStartJourney ?? () {},
      onRetry: onRetry ?? () {},
      extrasLoader: extrasLoader ?? _fakeExtras(),
    );

void main() {
  testWidgets('ready state renders the plain-language leg timeline',
      (tester) async {
    await _useTestSurface(tester);
    final journey = _journey();
    final walkMeters =
        DistanceCalculator.distanceMeters(_origin, _boarding);
    final rideMeters = DistanceCalculator.distanceMeters(_boarding, _alight);
    final destMeters = DistanceCalculator.distanceMeters(_alight, _destination);
    final walkMins = _minutes(walkMeters, 1.4);
    final rideMins = _minutes(rideMeters, 20000 / 3600);
    final destMins = _minutes(destMeters, 1.4);
    final totalTime = journey.totalEstimatedDuration;

    await tester.pumpWidget(_app(_card(journey: journey)));
    await tester.pumpAndSettle();

    expect(find.text('Walk $walkMins min to Jerusalem Stage'), findsOneWidget);
    expect(find.text('Board Route 58 towards Buruburu'), findsOneWidget);
    expect(find.text('$rideMins min'), findsOneWidget);
    expect(find.text('Get off at Buruburu (8 stops)'), findsOneWidget);
    expect(find.text('Walk $destMins min to your destination'), findsOneWidget);
    expect(find.text(_timeLabel(totalTime)), findsOneWidget);
    expect(
      find.text(DistanceFormatter.format(journey.totalDistanceMeters)),
      findsOneWidget,
    );
    expect(find.text('KSh 20-30'), findsOneWidget);
    expect(find.text('Matatus come every 5-15 min'), findsOneWidget);
    expect(find.text('Start Journey'), findsOneWidget);
  });

  testWidgets('Start Journey and option chips fire their callbacks',
      (tester) async {
    await _useTestSurface(tester);
    final journey = _journey();
    final options = [
      _option('58', seconds: 1200),
      _option('18', seconds: 1500),
    ];
    PathOption? chosen;
    var started = false;

    await tester.pumpWidget(_app(_card(
      journey: journey,
      pathOptions: options,
      selectedPath: options.first,
      onSelectOption: (option) => chosen = option,
      onStartJourney: () => started = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Journey'));
    expect(started, isTrue);

    final chipTwo = find.text('25 min · KSh 25');
    await tester.ensureVisible(chipTwo);
    await tester.pumpAndSettle();
    await tester.tap(chipTwo);
    await tester.pumpAndSettle();
    expect(chosen, isNotNull);
    expect(chosen, same(options.last));
  });

  testWidgets('loader failure hides headway, headsign and stop counts',
      (tester) async {
    await _useTestSurface(tester);
    await tester.pumpWidget(_app(_card(
      journey: _journey(),
      extrasLoader: (journey, stages) async => null,
    )));
    await tester.pumpAndSettle();

    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('Board Route 58'), findsOneWidget);
    expect(find.text('Get off at Buruburu'), findsOneWidget);
    expect(
      find.textContaining('Matatus come every'),
      findsNothing,
    );
  });

  testWidgets('loading state shows the shimmer skeleton without the CTA',
      (tester) async {
    await _useTestSurface(tester);
    await tester.pumpWidget(_app(_card(loading: true)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ShaderMask), findsWidgets);
    expect(find.text('Start Journey'), findsNothing);
    expect(find.text("Couldn't build your route."), findsNothing);
  });

  testWidgets('error state shows the Retry action and fires onRetry',
      (tester) async {
    await _useTestSurface(tester);
    var retried = false;
    await tester.pumpWidget(_app(_card(
      error: true,
      onRetry: () => retried = true,
    )));
    await tester.pump();

    expect(find.text("Couldn't build your route."), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('entrance slides up once and settles at zero offset',
      (tester) async {
    await _useTestSurface(tester);
    await tester.pumpWidget(_app(_card(journey: _journey())));
    await tester.pump();

    final finder = find.descendant(
      of: find.byType(PreTripCard),
      matching: find.byType(SlideTransition),
    );
    final slide = tester.widget<SlideTransition>(finder);
    expect(slide.position.value, isNot(Offset.zero));

    await tester.pump(const Duration(milliseconds: 350));
    final settled = tester.widget<SlideTransition>(finder);
    expect(settled.position.value, Offset.zero);
  });

  testWidgets('reduced motion skips the entrance slide entirely',
      (tester) async {
    await _useTestSurface(tester);
    await tester.pumpWidget(_app(
      _card(journey: _journey()),
      disableAnimations: true,
    ));
    await tester.pump();

    final slide = tester.widget<SlideTransition>(find.descendant(
      of: find.byType(PreTripCard),
      matching: find.byType(SlideTransition),
    ));
    expect(slide.position.value, Offset.zero);
  });

  testWidgets('dark theme paints the card shell with the dark canvas color',
      (tester) async {
    await _useTestSurface(tester);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(400, 1400)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 400,
              child: _card(journey: _journey()),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final shell = tester.widget<Container>(
      find.byKey(const Key('preTripCardShell')),
    );
    final decoration = shell.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF121212));
  });
}
