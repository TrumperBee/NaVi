import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/screens/navigation_overlay.dart';
import 'package:navi_app/widgets/journey_info_panel.dart';

void main() {
  const origin = LatLng(-1.2833, 36.8167);
  const boarding = LatLng(-1.2850, 36.8183);
  const alighting = LatLng(-1.2875, 36.8200);
  const destination = LatLng(-1.2890, 36.8220);

  ActiveJourney walkRideWalk() {
    return ActiveJourney(segments: [
      RouteSegment.walk(
        label: 'Walk to Stage A',
        coordinates: [origin, boarding],
        startPoint: origin,
        endPoint: boarding,
      ),
      RouteSegment.matatu(
        label: 'Ride Route 46 to Makadara',
        coordinates: [boarding, alighting],
        routeNumber: '46',
        startPoint: boarding,
        endPoint: alighting,
      ),
      RouteSegment.walk(
        label: 'Walk to destination',
        coordinates: [alighting, destination],
        startPoint: alighting,
        endPoint: destination,
      ),
    ]);
  }

  Widget harness(double height) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(400, height),
          disableAnimations: true,
        ),
        child: Scaffold(
          body: NavigationOverlay(
            map: const ColoredBox(
              key: Key('mapZone'),
              color: Color(0xFFCCCCCC),
            ),
            journey: walkRideWalk(),
            voiceGuidanceEnabled: true,
            onToggleVoiceGuidance: (_) {},
            onEndTrip: () {},
          ),
        ),
      ),
    );
  }

  group('mapZoneFlexFor', () {
    test('small phones use a 52/48 split', () {
      expect(NavigationOverlay.mapZoneFlexFor(599), equals((52, 48)));
    });

    test('medium screens use the 55/45 baseline', () {
      expect(NavigationOverlay.mapZoneFlexFor(600), equals((55, 45)));
      expect(NavigationOverlay.mapZoneFlexFor(700), equals((55, 45)));
      expect(NavigationOverlay.mapZoneFlexFor(900), equals((55, 45)));
    });

    test('large screens use a 57/43 split', () {
      expect(NavigationOverlay.mapZoneFlexFor(901), equals((57, 43)));
    });
  });

  group('NavigationOverlay layout', () {
    testWidgets('map sits in the top zone, info panel in the bottom zone',
        (tester) async {
      const height = 700.0;
      await tester.pumpWidget(harness(height));

      expect(find.byType(JourneyInfoPanel), findsOneWidget);
      expect(find.byKey(const Key('mapZone')), findsOneWidget);

      final mapZone = tester.getSize(find.byKey(const Key('mapZone')));
      final infoZone = tester.getSize(find.byType(JourneyInfoPanel));

      // The flex split is proportional: with a medium height (MediaQuery 700)
      // the 55/45 baseline applies. The real test canvas is 800x600, so assert
      // against the column's own total rather than a fabricated figure.
      final total = mapZone.height + infoZone.height;
      expect(mapZone.height / total, closeTo(0.55, 0.02),
          reason: 'map must own the visible majority (~55%)');
      expect(infoZone.height / total, closeTo(0.45, 0.02),
          reason: 'info panel must be a distinct ~45% bottom zone');
      expect(mapZone.height + infoZone.height, closeTo(600.0, 0.1));
    });

    testWidgets('maneuver banner floats over the map with the current step',
        (tester) async {
      await tester.pumpWidget(harness(700));

      expect(find.byType(ManeuverBanner), findsOneWidget);
      expect(find.text('WALKING'), findsOneWidget);
      expect(find.text('Walk to Stage A'), findsOneWidget);
    });

    testWidgets('info panel exposes the required journey content',
        (tester) async {
      await tester.pumpWidget(harness(700));

      expect(find.text('FINAL TIME'), findsOneWidget);
      expect(find.text('Walking to Stage A'), findsOneWidget);
      expect(find.text('UP NEXT'), findsOneWidget);
      expect(find.text('Ride Route 46 to Makadara'), findsOneWidget);
      expect(find.text('End Trip'), findsOneWidget);
    });
  });
}