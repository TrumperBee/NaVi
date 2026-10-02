import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/models/fare_estimate_record.dart';
import 'package:navi_app/services/fare_estimate_registry.dart';

void main() {
  FareEstimateRecord estimate({
    String route = '33',
    String from = 'kencom',
    String to = 'kicc',
    FareConfidence confidence = FareConfidence.unverified,
    int offpeak = 100,
    int peak = 150,
  }) {
    return FareEstimateRecord(
      routeId: route,
      fromStageId: from,
      toStageId: to,
      estimatedOffpeak: offpeak,
      estimatedPeak: peak,
      confidence: confidence,
      lastVerified: DateTime(2024, 6, 1),
      reportedBy: 'Victor',
    );
  }

  setUp(FareEstimateRegistry.clear);
  tearDown(FareEstimateRegistry.clear);

  test('defaults to an empty store (computed fares are the default)', () {
    expect(FareEstimateRegistry.all, isEmpty);
    expect(FareEstimateRegistry.findVerified('33', 'kencom', 'kicc'), isNull);
  });

  test('findVerified returns only the verified row for the exact tuple', () {
    FareEstimateRegistry.upsert(estimate());
    FareEstimateRegistry.upsert(
        estimate(confidence: FareConfidence.verified, offpeak: 120));

    final hit = FareEstimateRegistry.findVerified('33', 'kencom', 'kicc');
    expect(hit, isNotNull);
    expect(hit!.estimatedOffpeak, 120);

    // A different tuple never matches even when verified for the same route.
    expect(FareEstimateRegistry.findVerified('33', 'kencom', 'knh'), isNull);
    expect(FareEstimateRegistry.findVerified('34B', 'kencom', 'kicc'), isNull);
  });

  test('unverified rows never satisfy the resolution lookup', () {
    FareEstimateRegistry.upsert(estimate());
    expect(FareEstimateRegistry.findVerified('33', 'kencom', 'kicc'), isNull);
  });

  test('findAny exposes unverified rows for the review path', () {
    FareEstimateRegistry.upsert(estimate());
    final any = FareEstimateRegistry.findAny('33', 'kencom', 'kicc');
    expect(any, isNotNull);
    expect(any!.confidence, FareConfidence.unverified);
  });

  test('upsert replaces the existing row for the same tuple', () {
    FareEstimateRegistry.upsert(estimate(offpeak: 100));
    FareEstimateRegistry.upsert(estimate(offpeak: 120, peak: 200));

    final rows = FareEstimateRegistry.all
        .where((e) => e.key == '33|kencom|kicc')
        .toList();
    expect(rows, hasLength(1));
    expect(rows.single.estimatedOffpeak, 120);
    expect(rows.single.estimatedPeak, 200);
  });

  test('markVerified promotes a stored row and stamps it', () {
    final reviewedAt = DateTime(2024, 9, 1, 14);
    FareEstimateRegistry.upsert(estimate());

    FareEstimateRegistry.markVerified(
      routeId: '33',
      fromStageId: 'kencom',
      toStageId: 'kicc',
      verifiedAt: reviewedAt,
    );

    final row = FareEstimateRegistry.findVerified('33', 'kencom', 'kicc');
    expect(row, isNotNull);
    expect(row!.confidence, FareConfidence.verified);
    expect(row.lastVerified, reviewedAt);
  });

  test('markVerified is a no-op when no row exists for the tuple', () {
    FareEstimateRegistry.markVerified(
      routeId: '999',
      fromStageId: 'nowhere',
      toStageId: 'still_nowhere',
      verifiedAt: DateTime(2024, 9, 1),
    );
    expect(FareEstimateRegistry.all, isEmpty);
  });

  test('setEstimates swaps the active store and ignores empty input', () {
    FareEstimateRegistry.setEstimates([estimate()]);
    expect(FareEstimateRegistry.all, hasLength(1));

    // A failed load handing back [] must not wipe the live store.
    FareEstimateRegistry.setEstimates([]);
    expect(FareEstimateRegistry.all, hasLength(1));

    FareEstimateRegistry.clear();
    expect(FareEstimateRegistry.all, isEmpty);
  });
}