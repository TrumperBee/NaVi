import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/fare_estimate.dart' as fare;
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/widgets/journey_info_panel.dart';

void main() {
  const origin = LatLng(-1.2833, 36.8167);
  const boarding = LatLng(-1.2850, 36.8183);
  const alighting = LatLng(-1.2875, 36.8200);
  const destination = LatLng(-1.2890, 36.8220);

  RouteSegment walkSegment(String label, LatLng from, LatLng to) {
    return RouteSegment.walk(
      label: label,
      coordinates: [from, to],
      startPoint: from,
      endPoint: to,
    );
  }

  RouteSegment matatuSegment(int amountKsh) {
    final segment = RouteSegment.matatu(
      label: 'Ride Route 46 to Makadara',
      coordinates: [boarding, alighting],
      routeNumber: '46',
      startPoint: boarding,
      endPoint: alighting,
    );
    return segment.copyWith(
      fareEstimate: fare.FareEstimate.matatu(
        amountKsh: amountKsh,
        tier: fare.FareTier.short,
        timeOfDay: fare.TimeOfDay.offPeak,
      ),
    );
  }

  ActiveJourney journeyAt(int currentSegmentIndex) {
    return ActiveJourney(
      segments: [
        walkSegment('Walk to Stage A', origin, boarding),
        matatuSegment(60),
        walkSegment('Walk to destination', alighting, destination),
      ],
      currentSegmentIndex: currentSegmentIndex,
    );
  }

  Widget harness(
    ActiveJourney journey, {
    bool voiceGuidanceEnabled = true,
    ValueChanged<bool>? onToggleVoiceGuidance,
    VoidCallback? onEndTrip,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: Scaffold(
          body: JourneyInfoPanel(
            journey: journey,
            voiceGuidanceEnabled: voiceGuidanceEnabled,
            onToggleVoiceGuidance: onToggleVoiceGuidance ?? (_) {},
            onEndTrip: onEndTrip ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows remaining time and distance in the header',
      (tester) async {
    await tester.pumpWidget(harness(journeyAt(0)));

    expect(find.text('FINAL TIME'), findsOneWidget);
    expect(find.text('DISTANCE'), findsOneWidget);
    expect(find.textContaining('min'), findsWidgets);
    expect(find.textContaining('m'), findsWidgets);
  });

  testWidgets('shows the waking current step in plain language',
      (tester) async {
    await tester.pumpWidget(harness(journeyAt(0)));

    expect(find.text('Walking to Stage A'), findsOneWidget);
    expect(find.byIcon(Icons.directions_walk), findsWidgets);
    expect(find.text('Continue on foot'), findsOneWidget);
  });

  testWidgets('shows the matatu current step with route badge on board',
      (tester) async {
    await tester.pumpWidget(harness(journeyAt(1)));

    expect(find.text('On Route 46 to Makadara'), findsOneWidget);
    expect(find.text('46'), findsOneWidget,
        reason: 'the route number badge shows while riding');
  });

  testWidgets('previews the next steps in secondary styling', (tester) async {
    await tester.pumpWidget(harness(journeyAt(0)));

    expect(find.text('UP NEXT'), findsOneWidget);
    expect(find.text('Ride Route 46 to Makadara'), findsOneWidget);
    expect(find.text('Walk to destination'), findsOneWidget);
  });

  testWidgets('hides the fare row before boarding (walk-only so far)',
      (tester) async {
    await tester.pumpWidget(harness(journeyAt(0)));
    expect(find.text('FARE SO FAR'), findsNothing);
    expect(find.textContaining('KSh'), findsNothing);
  });

  testWidgets('shows the running fare once boarding begins', (tester) async {
    await tester.pumpWidget(harness(journeyAt(1)));
    expect(find.text('FARE SO FAR'), findsOneWidget);
    expect(find.text('KSh 60'), findsOneWidget);
  });

  testWidgets('always stays at KSh 0 and hides the fare on walk-only routes',
      (tester) async {
    final walkOnly = ActiveJourney(segments: [
      walkSegment('Walk to Stage A', origin, boarding),
      walkSegment('Walk to destination', boarding, destination),
    ]);
    await tester.pumpWidget(harness(walkOnly));
    expect(find.text('FARE SO FAR'), findsNothing);
  });

  testWidgets('voice toggle calls back with the flipped value',
      (tester) async {
    bool? toggledTo;
    await tester.pumpWidget(harness(
      journeyAt(0),
      voiceGuidanceEnabled: false,
      onToggleVoiceGuidance: (value) => toggledTo = value,
    ));

    expect(find.text('Off'), findsOneWidget);
    await tester.tap(find.text('Off'));
    expect(toggledTo, isTrue);

    await tester.pumpWidget(harness(
      journeyAt(0),
      voiceGuidanceEnabled: true,
      onToggleVoiceGuidance: (value) => toggledTo = value,
    ));
    expect(find.text('On'), findsOneWidget);
    await tester.tap(find.text('On'));
    expect(toggledTo, isFalse);
  });

  testWidgets('End Trip invokes the callback', (tester) async {
    var ended = false;
    await tester.pumpWidget(
        harness(journeyAt(1), onEndTrip: () => ended = true));

    expect(find.text('End Trip'), findsOneWidget);
    await tester.tap(find.text('End Trip'));
    expect(ended, isTrue);
  });

  testWidgets('shows the arrived state once the journey is complete',
      (tester) async {
    await tester.pumpWidget(harness(journeyAt(3)));

    expect(find.text('Arrived at your destination'), findsOneWidget);
    expect(find.text('Journey complete'), findsOneWidget);
    expect(find.text('End Trip'), findsOneWidget);
  });
}