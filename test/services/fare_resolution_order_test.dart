import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/features/community/services/fare_intelligence_service.dart';
import 'package:navi_app/models/fare_estimate.dart';
import 'package:navi_app/models/fare_estimate_record.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/services/fare_calculator_service.dart';
import 'package:navi_app/services/fare_estimate_registry.dart';

void main() {
  // Route "33" is a long-tier corridor: the computed value is deterministic —
  // KSh 150 at peak, KSh 100 off-peak — which makes override vs fallback
  // comparisons exact rather than range-based.
  final peakAt = DateTime(2024, 1, 15, 18, 0);
  final offPeakAt = DateTime(2024, 1, 15, 13, 0);

  RouteSegment leg({
    String route = '33',
    String? fromStageId = 'kencom',
    String? toStageId = 'kicc',
  }) {
    return RouteSegment.matatu(
      label: 'Ride Route $route',
      coordinates: const [
        LatLng(-1.2833, 36.8167),
        LatLng(-1.3400, 36.8700),
      ],
      routeNumber: route,
      startPoint: const LatLng(-1.2833, 36.8167),
      endPoint: const LatLng(-1.3400, 36.8700),
      fromStageId: fromStageId,
      toStageId: toStageId,
    );
  }

  setUp(FareEstimateRegistry.clear);
  tearDown(FareEstimateRegistry.clear);

  group('§1.6 fare resolution order', () {
    test('no estimate on file falls back to the computed value', () {
      expect(
        FareCalculatorService.calculateFare(leg(), atTime: peakAt).amountKsh,
        150,
      );
      expect(
        FareCalculatorService.calculateFare(leg(), atTime: offPeakAt).amountKsh,
        100,
      );
    });

    test('a verified estimate for the exact tuple wins at both periods', () {
      FareEstimateRegistry.upsert(FareEstimateRecord(
        routeId: '33',
        fromStageId: 'kencom',
        toStageId: 'kicc',
        estimatedOffpeak: 120,
        estimatedPeak: 180,
        confidence: FareConfidence.verified,
        lastVerified: DateTime(2024, 6, 1),
        reportedBy: 'Victor',
      ));

      final peakFare =
          FareCalculatorService.calculateFare(leg(), atTime: peakAt);
      expect(peakFare.amountKsh, 180);
      expect(peakFare.timeOfDay, TimeOfDay.peak);

      final offpeakFare =
          FareCalculatorService.calculateFare(leg(), atTime: offPeakAt);
      expect(offpeakFare.amountKsh, 120);
      expect(offpeakFare.timeOfDay, TimeOfDay.offPeak);
    });

    test('a verified estimate for a DIFFERENT tuple does not leak in', () {
      FareEstimateRegistry.upsert(FareEstimateRecord(
        routeId: '33',
        fromStageId: 'kencom',
        toStageId: 'knh',
        estimatedOffpeak: 120,
        estimatedPeak: 180,
        confidence: FareConfidence.verified,
        lastVerified: DateTime(2024, 6, 1),
      ));

      expect(
        FareCalculatorService.calculateFare(leg(), atTime: peakAt).amountKsh,
        150,
      );
    });

    test('an UNVERIFIED estimate never overrides the computed value', () {
      FareEstimateRegistry.upsert(FareEstimateRecord(
        routeId: '33',
        fromStageId: 'kencom',
        toStageId: 'kicc',
        estimatedOffpeak: 20,
        estimatedPeak: 40,
        confidence: FareConfidence.unverified,
        lastVerified: DateTime(2024, 6, 1),
        reportedBy: 'Friend',
      ));

      expect(
        FareCalculatorService.calculateFare(leg(), atTime: peakAt).amountKsh,
        150,
      );
      expect(
        FareCalculatorService.calculateFare(leg(), atTime: offPeakAt).amountKsh,
        100,
      );
    });

    test('walking legs are never touched by the override layer', () {
      FareEstimateRegistry.upsert(FareEstimateRecord(
        routeId: '33',
        fromStageId: 'kencom',
        toStageId: 'kicc',
        estimatedOffpeak: 120,
        estimatedPeak: 180,
        confidence: FareConfidence.verified,
        lastVerified: DateTime(2024, 6, 1),
      ));

      final walk = RouteSegment.walk(
        label: 'Walk to stage',
        coordinates: const [
          LatLng(-1.2833, 36.8167),
          LatLng(-1.2850, 36.8183),
        ],
        startPoint: const LatLng(-1.2833, 36.8167),
        endPoint: const LatLng(-1.2850, 36.8183),
      );
      expect(FareCalculatorService.calculateFare(walk, atTime: peakAt).amountKsh,
          0);
    });

    test('a leg without staged boundaries cannot trigger an override', () {
      FareEstimateRegistry.upsert(FareEstimateRecord(
        routeId: '33',
        fromStageId: 'kencom',
        toStageId: 'kicc',
        estimatedOffpeak: 120,
        estimatedPeak: 180,
        confidence: FareConfidence.verified,
        lastVerified: DateTime(2024, 6, 1),
      ));

      final unStaged = leg(fromStageId: null, toStageId: null);
      expect(
        FareCalculatorService.calculateFare(unStaged, atTime: peakAt).amountKsh,
        150,
      );
    });

    test('a reported amount of 0 is never displayed — falls back to computed', () {
      FareEstimateRegistry.upsert(FareEstimateRecord(
        routeId: '33',
        fromStageId: 'kencom',
        toStageId: 'kicc',
        estimatedOffpeak: 0,
        estimatedPeak: 180,
        confidence: FareConfidence.verified,
        lastVerified: DateTime(2024, 6, 1),
      ));

      // Bad off-peak value → computed 100, not raw 0.
      expect(
        FareCalculatorService.calculateFare(leg(), atTime: offPeakAt).amountKsh,
        100,
      );
      // Peak still honours the sane reported value.
      expect(
        FareCalculatorService.calculateFare(leg(), atTime: peakAt).amountKsh,
        180,
      );
    });
  });

  group('contributor report → review → displayed fare (end-to-end)', () {
    test('a submission goes in unverified, is ignored, then honoured once '
        'a reviewer verifies it', () {
      final service = FareIntelligenceService();

      // A contributor reports the observed kencom → kicc fare on route 33.
      service.submitRouteFareEstimate(
        routeId: '33',
        fromStageId: 'kencom',
        toStageId: 'kicc',
        estimatedOffpeak: 120,
        estimatedPeak: 180,
        reportedBy: 'Friend',
        observedAt: DateTime(2024, 6, 1, 8),
      );

      // Stored for review, but the display path ignores it.
      final stored = FareEstimateRegistry.findAny('33', 'kencom', 'kicc');
      expect(stored, isNotNull);
      expect(stored!.confidence, FareConfidence.unverified);
      expect(FareEstimateRegistry.findVerified('33', 'kencom', 'kicc'), isNull);
      expect(
        FareCalculatorService.calculateFare(leg(), atTime: peakAt).amountKsh,
        150,
      );

      // Reviewer gate promotes it.
      service.verifyRouteFareEstimate(
        routeId: '33',
        fromStageId: 'kencom',
        toStageId: 'kicc',
        verifiedAt: DateTime(2024, 6, 2, 10),
      );

      final verified = FareEstimateRegistry.findVerified('33', 'kencom', 'kicc');
      expect(verified, isNotNull);
      expect(verified!.estimatedPeak, 180);
      expect(verified.reportedBy, 'Friend');
      expect(FareCalculatorService.calculateFare(leg(), atTime: peakAt).amountKsh,
          180);
      expect(
        FareCalculatorService.calculateFare(leg(), atTime: offPeakAt).amountKsh,
        120,
      );
    });
  });
}