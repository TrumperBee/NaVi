import 'package:test/test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/services/fare_calculator_service.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/models/fare_estimate.dart';
import 'package:navi_app/models/proximity_threshold.dart';
import 'package:navi_app/data/fare_matrix_seed.dart';

void main() {
  group('FareCalculatorService', () {
    group('calculateFare', () {
      test('walk segment returns 0 fare', () {
        final segment = RouteSegment.walk(
          label: 'Walk to stage',
          coordinates: [
            const LatLng(-1.2833, 36.8167),
            const LatLng(-1.2850, 36.8183),
          ],
          startPoint: const LatLng(-1.2833, 36.8167),
          endPoint: const LatLng(-1.2850, 36.8183),
        );

        final fare = FareCalculatorService.calculateFare(
          segment,
          atTime: DateTime(2024, 1, 15, 7, 0), // peak
        );

        expect(fare.amountKsh, equals(0));
        expect(fare.isWalking, isTrue);
        expect(fare.timeOfDay, equals(TimeOfDay.peak));
      });

      test('walk segment returns 0 fare at off-peak', () {
        final segment = RouteSegment.walk(
          label: 'Walk to stage',
          coordinates: [
            const LatLng(-1.2833, 36.8167),
            const LatLng(-1.2850, 36.8183),
          ],
          startPoint: const LatLng(-1.2833, 36.8167),
          endPoint: const LatLng(-1.2850, 36.8183),
        );

        final fare = FareCalculatorService.calculateFare(
          segment,
          atTime: DateTime(2024, 1, 15, 13, 0), // off-peak
        );

        expect(fare.amountKsh, equals(0));
        expect(fare.isWalking, isTrue);
        expect(fare.timeOfDay, equals(TimeOfDay.offPeak));
      });

      test('short-tier matatu segment at peak returns value in [30, 50]', () {
        final segment = RouteSegment.matatu(
          label: 'Ride Route 58',
          coordinates: [
            const LatLng(-1.2850, 36.8183),
            const LatLng(-1.2875, 36.8200),
          ],
          routeNumber: '58',
          startPoint: const LatLng(-1.2850, 36.8183),
          endPoint: const LatLng(-1.2875, 36.8200),
        );

        final fare = FareCalculatorService.calculateFare(
          segment,
          atTime: DateTime(2024, 1, 15, 7, 0), // peak
        );

        expect(fare.amountKsh, greaterThanOrEqualTo(30));
        expect(fare.amountKsh, lessThanOrEqualTo(50));
        expect(fare.isWalking, isFalse);
        expect(fare.tier, equals(FareTier.short));
        expect(fare.timeOfDay, equals(TimeOfDay.peak));
        expect(FareMatrix.getStandardDenominations().contains(fare.amountKsh), isTrue);
      });

      test('short-tier matatu segment at off-peak returns value in [20, 30]', () {
        final segment = RouteSegment.matatu(
          label: 'Ride Route 58',
          coordinates: [
            const LatLng(-1.2850, 36.8183),
            const LatLng(-1.2875, 36.8200),
          ],
          routeNumber: '58',
          startPoint: const LatLng(-1.2850, 36.8183),
          endPoint: const LatLng(-1.2875, 36.8200),
        );

        final fare = FareCalculatorService.calculateFare(
          segment,
          atTime: DateTime(2024, 1, 15, 13, 0), // off-peak
        );

        expect(fare.amountKsh, greaterThanOrEqualTo(20));
        expect(fare.amountKsh, lessThanOrEqualTo(30));
        expect(fare.isWalking, isFalse);
        expect(fare.tier, equals(FareTier.short));
        expect(fare.timeOfDay, equals(TimeOfDay.offPeak));
        expect(FareMatrix.getStandardDenominations().contains(fare.amountKsh), isTrue);
      });

      test('long-tier matatu segment at peak returns exactly 150', () {
        final segment = RouteSegment.matatu(
          label: 'Ride Route 33',
          coordinates: [
            const LatLng(-1.2833, 36.8167),
            const LatLng(-1.3400, 36.8700),
          ],
          routeNumber: '33',
          startPoint: const LatLng(-1.2833, 36.8167),
          endPoint: const LatLng(-1.3400, 36.8700),
        );

        final fare = FareCalculatorService.calculateFare(
          segment,
          atTime: DateTime(2024, 1, 15, 18, 0), // peak
        );

        expect(fare.amountKsh, equals(150));
        expect(fare.tier, equals(FareTier.long));
        expect(fare.timeOfDay, equals(TimeOfDay.peak));
      });

      test('long-tier matatu segment at off-peak returns exactly 100', () {
        final segment = RouteSegment.matatu(
          label: 'Ride Route 33',
          coordinates: [
            const LatLng(-1.2833, 36.8167),
            const LatLng(-1.3400, 36.8700),
          ],
          routeNumber: '33',
          startPoint: const LatLng(-1.2833, 36.8167),
          endPoint: const LatLng(-1.3400, 36.8700),
        );

        final fare = FareCalculatorService.calculateFare(
          segment,
          atTime: DateTime(2024, 1, 15, 13, 0), // off-peak
        );

        expect(fare.amountKsh, equals(100));
        expect(fare.tier, equals(FareTier.long));
        expect(fare.timeOfDay, equals(TimeOfDay.offPeak));
      });

      test('rounding always rounds up to standard denomination', () {
        final segment = RouteSegment.matatu(
          label: 'Ride Route 58',
          coordinates: [
            const LatLng(-1.2850, 36.8183),
            const LatLng(-1.2875, 36.8200),
          ],
          routeNumber: '58',
          startPoint: const LatLng(-1.2850, 36.8183),
          endPoint: const LatLng(-1.2875, 36.8200),
        );

        // Test multiple times at peak to ensure rounding up
        for (int i = 0; i < 10; i++) {
          final fare = FareCalculatorService.calculateFare(
            segment,
            atTime: DateTime(2024, 1, 15, 7, i),
          );
          expect(FareMatrix.getStandardDenominations().contains(fare.amountKsh), isTrue,
              reason: 'Fare ${fare.amountKsh} is not a standard denomination');
        }
      });
    });

    group('calculateJourneyTotal', () {
      test('sums correctly for walk + matatu + walk', () {
        final segments = [
          RouteSegment.walk(
            label: 'Walk to stage',
            coordinates: [
              const LatLng(-1.2833, 36.8167),
              const LatLng(-1.2850, 36.8183),
            ],
            startPoint: const LatLng(-1.2833, 36.8167),
            endPoint: const LatLng(-1.2850, 36.8183),
          ),
          RouteSegment.matatu(
            label: 'Ride Route 58',
            coordinates: [
              const LatLng(-1.2850, 36.8183),
              const LatLng(-1.2875, 36.8200),
            ],
            routeNumber: '58',
            startPoint: const LatLng(-1.2850, 36.8183),
            endPoint: const LatLng(-1.2875, 36.8200),
          ),
          RouteSegment.walk(
            label: 'Walk to destination',
            coordinates: [
              const LatLng(-1.2875, 36.8200),
              const LatLng(-1.2900, 36.8220),
            ],
            startPoint: const LatLng(-1.2875, 36.8200),
            endPoint: const LatLng(-1.2900, 36.8220),
          ),
        ];

        final total = FareCalculatorService.calculateJourneyTotal(
          segments,
          atTime: DateTime(2024, 1, 15, 7, 0),
        );

        // Only the matatu segment contributes to fare
        expect(total, greaterThanOrEqualTo(30));
        expect(total, lessThanOrEqualTo(50));
      });

      test('walk segments contribute 0 to total', () {
        final segments = [
          RouteSegment.walk(
            label: 'Walk 1',
            coordinates: [
              const LatLng(-1.2833, 36.8167),
              const LatLng(-1.2850, 36.8183),
            ],
            startPoint: const LatLng(-1.2833, 36.8167),
            endPoint: const LatLng(-1.2850, 36.8183),
          ),
          RouteSegment.walk(
            label: 'Walk 2',
            coordinates: [
              const LatLng(-1.2875, 36.8200),
              const LatLng(-1.2900, 36.8220),
            ],
            startPoint: const LatLng(-1.2875, 36.8200),
            endPoint: const LatLng(-1.2900, 36.8220),
          ),
        ];

        final total = FareCalculatorService.calculateJourneyTotal(
          segments,
          atTime: DateTime(2024, 1, 15, 7, 0),
        );

        expect(total, equals(0));
      });
    });

    group('FareMatrix', () {
      test('getTimeOfDay returns peak for 07:00', () {
        final timeOfDay = FareMatrix.getTimeOfDay(DateTime(2024, 1, 15, 7, 0));
        expect(timeOfDay, equals(TimeOfDay.peak));
      });

      test('getTimeOfDay returns peak for 18:00', () {
        final timeOfDay = FareMatrix.getTimeOfDay(DateTime(2024, 1, 15, 18, 0));
        expect(timeOfDay, equals(TimeOfDay.peak));
      });

      test('getTimeOfDay returns offPeak for 13:00', () {
        final timeOfDay = FareMatrix.getTimeOfDay(DateTime(2024, 1, 15, 13, 0));
        expect(timeOfDay, equals(TimeOfDay.offPeak));
      });

      test('getTimeOfDay returns offPeak for 22:00', () {
        final timeOfDay = FareMatrix.getTimeOfDay(DateTime(2024, 1, 15, 22, 0));
        expect(timeOfDay, equals(TimeOfDay.offPeak));
      });

      test('roundToStandardDenomination rounds up correctly', () {
        expect(FareMatrix.roundToStandardDenomination(21), equals(30));
        expect(FareMatrix.roundToStandardDenomination(31), equals(50));
        expect(FareMatrix.roundToStandardDenomination(51), equals(80));
        expect(FareMatrix.roundToStandardDenomination(81), equals(100));
        expect(FareMatrix.roundToStandardDenomination(101), equals(150));
        expect(FareMatrix.roundToStandardDenomination(20), equals(20));
        expect(FareMatrix.roundToStandardDenomination(150), equals(150));
        expect(FareMatrix.roundToStandardDenomination(151), equals(150)); // caps at max
      });

      test('getFareRange returns correct ranges', () {
        expect(FareMatrix.getFareRange(FareTier.short, TimeOfDay.offPeak), equals([20, 30]));
        expect(FareMatrix.getFareRange(FareTier.short, TimeOfDay.peak), equals([30, 50]));
        expect(FareMatrix.getFareRange(FareTier.medium, TimeOfDay.offPeak), equals([50, 80]));
        expect(FareMatrix.getFareRange(FareTier.medium, TimeOfDay.peak), equals([80, 100]));
        expect(FareMatrix.getFareRange(FareTier.long, TimeOfDay.offPeak), equals([100, 100]));
        expect(FareMatrix.getFareRange(FareTier.long, TimeOfDay.peak), equals([150, 150]));
      });

      test('standard denominations are correct', () {
        expect(FareMatrix.getStandardDenominations(), equals([20, 30, 50, 80, 100, 150]));
      });
    });

    group('TimeOfDay detection', () {
      test('peak morning: 06:30 - 09:30', () {
        expect(FareMatrix.getTimeOfDay(DateTime(2024, 1, 15, 6, 30)), equals(TimeOfDay.peak));
        expect(FareMatrix.getTimeOfDay(DateTime(2024, 1, 15, 7, 0)), equals(TimeOfDay.peak));
        expect(FareMatrix.getTimeOfDay(DateTime(2024, 1, 15, 9, 30)), equals(TimeOfDay.peak));
        expect(FareMatrix.getTimeOfDay(DateTime(2024, 1, 15, 9, 31)), equals(TimeOfDay.offPeak));
      });

      test('peak evening: 16:30 - 20:00', () {
        expect(FareMatrix.getTimeOfDay(DateTime(2024, 1, 15, 16, 30)), equals(TimeOfDay.peak));
        expect(FareMatrix.getTimeOfDay(DateTime(2024, 1, 15, 18, 0)), equals(TimeOfDay.peak));
        expect(FareMatrix.getTimeOfDay(DateTime(2024, 1, 15, 20, 0)), equals(TimeOfDay.peak));
        expect(FareMatrix.getTimeOfDay(DateTime(2024, 1, 15, 20, 1)), equals(TimeOfDay.offPeak));
      });
    });
  });
}