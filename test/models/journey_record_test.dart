import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/journey_record.dart';
import 'package:navi_app/models/route_segment.dart';

final _matatuLegs = [
  RouteSegment.walk(
    label: 'Walk to Kencom Bus Station',
    coordinates: const [
      LatLng(-1.2842, 36.8172),
      LatLng(-1.2833, 36.8167),
    ],
    startPoint: const LatLng(-1.2842, 36.8172),
    endPoint: const LatLng(-1.2833, 36.8167),
  ),
  RouteSegment.matatu(
    label: 'Ride Route 44 to Githurai 45 Stage',
    coordinates: const [
      LatLng(-1.2833, 36.8167),
      LatLng(-1.2083, 36.9000),
    ],
    routeNumber: '44',
    startPoint: const LatLng(-1.2833, 36.8167),
    endPoint: const LatLng(-1.2083, 36.9000),
  ),
  RouteSegment.walk(
    label: 'Walk to Home',
    coordinates: const [
      LatLng(-1.2083, 36.9000),
      LatLng(-1.2080, 36.9005),
    ],
    startPoint: const LatLng(-1.2083, 36.9000),
    endPoint: const LatLng(-1.2080, 36.9005),
  ),
];

ActiveJourney _buildJourney({List<RouteSegment>? segments}) =>
    ActiveJourney(segments: segments ?? _matatuLegs);

void main() {
  group('JourneyRecord', () {
    test('fromJourney extracts matatu alighting stages from labels', () {
      final journey = _buildJourney();
      final record = JourneyRecord.fromJourney(
        journey,
        originLabel: 'Mulhongo Close',
        destinationLabel: 'Home',
      );

      // Walk legs are ignored; matatu label "Ride Route 44 to X" yields X.
      expect(record.stageNames, ['Githurai 45 Stage']);
      expect(record.distanceKm,
          closeTo(journey.totalDistanceMeters / 1000, 0.0001));
      expect(record.fareKsh, journey.fareTotalKsh);
      expect(record.durationMinutes, journey.totalEstimatedDuration.inMinutes);
    });

    test('fromJourney falls back to generic labels when blank', () {
      final record = JourneyRecord.fromJourney(
        _buildJourney(),
        originLabel: '   ',
        destinationLabel: '',
      );

      expect(record.originLabel, 'Current location');
      expect(record.destinationLabel, 'Destination');
    });

    test('fromJourney tolerates a pure-walk trip (no stage names)', () {
      final walkOnly = ActiveJourney(segments: [
        RouteSegment.walk(
          label: 'Walk to Railways Bus Station',
          coordinates: const [
            LatLng(-1.2842, 36.8172),
            LatLng(-1.2875, 36.8200),
          ],
          startPoint: const LatLng(-1.2842, 36.8172),
          endPoint: const LatLng(-1.2875, 36.8200),
        ),
      ]);

      final record = JourneyRecord.fromJourney(
        walkOnly,
        originLabel: 'Office',
        destinationLabel: 'Railways Bus Station',
      );

      expect(record.stageNames, isEmpty);
      expect(record.fareKsh, 0);
    });

    test('toJson/fromJson round-trips every field', () {
      final record = JourneyRecord(
        date: DateTime(2026, 9, 26, 8, 30),
        originLabel: 'Mulhongo Close',
        destinationLabel: 'Githurai 45 Stage',
        distanceKm: 18.4,
        fareKsh: 120,
        durationMinutes: 47,
        stageNames: const ['Githurai 45 Stage', 'Roysambu Stage'],
      );

      final decoded = JourneyRecord.fromJson(record.toJson());

      expect(decoded.date, record.date);
      expect(decoded.originLabel, record.originLabel);
      expect(decoded.destinationLabel, record.destinationLabel);
      expect(decoded.distanceKm, record.distanceKm);
      expect(decoded.fareKsh, record.fareKsh);
      expect(decoded.durationMinutes, record.durationMinutes);
      expect(decoded.stageNames, record.stageNames);
      expect(decoded.distanceMeters, closeTo(18400, 0.001));
    });

    test('fromJson rejects malformed JSON', () {
      // The SettingsService caller tolerates the throw (see settings test).
      expect(() => JourneyRecord.fromJson('not-json'), throwsFormatException);
    });
  });
}