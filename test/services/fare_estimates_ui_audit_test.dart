import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/fare_estimate_record.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/models/journey_record.dart';
import 'package:navi_app/services/fare_calculator_service.dart';
import 'package:navi_app/services/fare_estimate_registry.dart';

/// The §1.6 read-path audit: the fare_estimates store is a persistence/
/// resolution detail. No presentation layer may read it directly — a fare
/// only reaches pixels via the calculator's resolution order. This mirrors the
/// earlier RouteRecord fare audit ("zero UI paths read the unset field"),
/// applied to the new entity.
void main() {
  // lib/features/community/services is excluded deliberately: it is the
  // WRITE path (FareIntelligenceService) that owns the store. The scan covers
  // every layer that renders or wires state for display.
  const kDisplayDirectories = [
    'lib/widgets',
    'lib/providers',
    'lib/screens',
    'lib/features/community/screens',
    'lib/features/community/providers',
  ];

  setUp(FareEstimateRegistry.clear);
  tearDown(FareEstimateRegistry.clear);

  test('display layer source never reads the fare_estimates store directly',
      () {
    const forbiddenSymbols = ['FareEstimateRegistry', 'FareEstimateRecord'];
    final offenders = <String>[];

    for (final dir in kDisplayDirectories) {
      final root = Directory(dir);
      if (!root.existsSync()) continue;
      for (final file in root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final content = file.readAsStringSync();
        for (final symbol in forbiddenSymbols) {
          if (content.contains(symbol)) {
            offenders.add('${file.path}: references $symbol');
          }
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'presentation layer must reach fares only through '
            'FareCalculatorService (via RouteSegment.fareEstimate). Raw store '
            'reads: ${offenders.join('\n')}');
  });

  matatuLeg() => RouteSegment.matatu(
        label: 'Ride Route 33',
        coordinates: const [
          LatLng(-1.2833, 36.8167),
          LatLng(-1.3400, 36.8700),
        ],
        routeNumber: '33',
        startPoint: const LatLng(-1.2833, 36.8167),
        endPoint: const LatLng(-1.3400, 36.8700),
        fromStageId: 'kencom',
        toStageId: 'kicc',
      );

  test('display aggregates honour a verified estimate only through the '
      'calculator, never a raw store read', () {
    FareEstimateRegistry.upsert(FareEstimateRecord(
      routeId: '33',
      fromStageId: 'kencom',
      toStageId: 'kicc',
      estimatedOffpeak: 120,
      estimatedPeak: 180,
      confidence: FareConfidence.verified,
      lastVerified: DateTime(2024, 6, 1),
    ));

    // Production builds segments via RouteBuilderService, which stamps
    // fareEstimate from calculateFare — the only sanctioned read.
    final leg = matatuLeg().copyWith(
      fareEstimate: FareCalculatorService.calculateFare(
        matatuLeg(),
        atTime: DateTime(2024, 1, 15, 18, 0),
      ),
    );

    final journey = ActiveJourney(segments: [leg]);
    expect(journey.fareTotalKsh, 180);

    final record = JourneyRecord.fromJourney(
      journey,
      originLabel: 'Current location',
      destinationLabel: 'KICC',
    );
    expect(record.fareKsh, 180);

    // A later unverified re-submission supersedes the verified row and is
    // inert: the display keeps the already-resolved stamped fare (180), and no
    // amount the store now holds can reach a user.
    FareEstimateRegistry.upsert(FareEstimateRecord(
      routeId: '33',
      fromStageId: 'kencom',
      toStageId: 'kicc',
      estimatedOffpeak: 20,
      estimatedPeak: 30,
      confidence: FareConfidence.unverified,
      lastVerified: DateTime(2024, 6, 1),
    ));
    expect(journey.fareTotalKsh, 180);
    expect(FareEstimateRegistry.findVerified('33', 'kencom', 'kicc'), isNull);
  });
}