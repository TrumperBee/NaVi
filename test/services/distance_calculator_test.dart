import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;

import 'package:navi_app/services/distance_calculator.dart';
import 'package:navi_app/utils/geo_utils.dart';

void main() {
  // Nairobi CBD stage as the reference origin (the same coordinates the old
  // stage sheet incorrectly hardcoded as "user location").
  const cbd = LatLng(-1.2833, 36.8167);
  // A stage roughly 750 m from the CBD (Makadara corridor).
  const stage = LatLng(-1.2899, 36.8235);

  group('DistanceCalculator', () {
    test('uses the single shared walking-speed constant', () {
      expect(DistanceCalculator.kWalkingSpeedMps, 1.4);
    });

    test('distanceMeters matches the canonical haversine helper', () {
      final expected = haversineDistance(
        cbd.latitude, cbd.longitude, stage.latitude, stage.longitude,
      );
      expect(DistanceCalculator.distanceMeters(cbd, stage), expected);
    });

    test('walkingDistanceAndTime returns a typed, consistent result', () {
      final result = DistanceCalculator.walkingDistanceAndTime(cbd, stage);

      expect(result.distanceMeters,
          DistanceCalculator.distanceMeters(cbd, stage));
      expect(result.walkDuration,
          (result.distanceMeters / DistanceCalculator.kWalkingSpeedMps).round());

      // The distance-only entry point agrees with the distance+time one, so
      // the home screen's "N min walk" label can never diverge from the sheet.
      expect(DistanceCalculator.walkDurationForDistance(result.distanceMeters),
          result.walkDuration);
    });

    test('both screens derive the same minutes from the same position', () {
      // Home hero card: min walk = round(walkDuration / 60).
      // Stage sheet: same expression fed by the SAME shared calculator.
      final result = DistanceCalculator.walkingDistanceAndTime(cbd, stage);
      final homeMinutes = (result.walkDuration / 60).round();
      final sheetMinutes =
          (DistanceCalculator.walkDurationForDistance(result.distanceMeters) /
                  60)
              .round();
      expect(sheetMinutes, homeMinutes);
    });

    test('is deterministic for a fixed position (no live-fix drift)', () {
      final a = DistanceCalculator.walkingDistanceAndTime(cbd, stage);
      final b = DistanceCalculator.walkingDistanceAndTime(cbd, stage);
      expect(a.distanceMeters, b.distanceMeters);
      expect(a.walkDuration, b.walkDuration);
    });
  });
}