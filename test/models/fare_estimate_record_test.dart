import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/models/fare_estimate_record.dart';

void main() {
  group('FareEstimateRecord', () {
    final sample = FareEstimateRecord(
      routeId: '33',
      fromStageId: 'kencom',
      toStageId: 'kicc',
      estimatedOffpeak: 100,
      estimatedPeak: 150,
      confidence: FareConfidence.verified,
      lastVerified: DateTime(2024, 6, 1, 10),
      reportedBy: 'Victor',
    );

    test('enum values match the spec §6 confidence semantics', () {
      expect(FareConfidence.values, [
        FareConfidence.verified,
        FareConfidence.unverified,
        FareConfidence.disputed,
      ]);
    });

    test('defaults: unverified confidence, null reporter', () {
      final record = FareEstimateRecord(
        routeId: '34B',
        fromStageId: 'nairobi_house',
        toStageId: 'kilimani',
        estimatedOffpeak: 60,
        estimatedPeak: 80,
        lastVerified: DateTime(2024, 6, 1),
      );
      expect(record.confidence, FareConfidence.unverified);
      expect(record.reportedBy, isNull);
    });

    test('serialization round-trip preserves every field', () {
      final revived = FareEstimateRecord.fromMap(sample.toMap());
      expect(revived.routeId, '33');
      expect(revived.fromStageId, 'kencom');
      expect(revived.toStageId, 'kicc');
      expect(revived.estimatedOffpeak, 100);
      expect(revived.estimatedPeak, 150);
      expect(revived.confidence, FareConfidence.verified);
      expect(revived.lastVerified, sample.lastVerified);
      expect(revived.reportedBy, 'Victor');
    });

    test('fromMap parses confidence names and falls back on unknown strings', () {
      final verified = FareEstimateRecord.fromMap({
        ...sample.toMap(),
        'confidence': 'disputed',
      });
      expect(verified.confidence, FareConfidence.disputed);

      final garbage = FareEstimateRecord.fromMap({
        ...sample.toMap(),
        'confidence': 'maybe',
      });
      expect(garbage.confidence, FareConfidence.unverified);
    });

    test('fromMap tolerates missing optional keys', () {
      final record = FareEstimateRecord.fromMap({
        'route_id': '33',
        'from_stage_id': 'kencom',
        'to_stage_id': 'kicc',
        'estimated_offpeak': 100,
        'estimated_peak': 150,
      });
      expect(record.confidence, FareConfidence.unverified);
      expect(record.reportedBy, isNull);
      expect(record.lastVerified, isNotNull);
    });

    test('key is the exact resolution tuple', () {
      expect(sample.key, '33|kencom|kicc');
    });

    test('amountAt picks the period-appropriate fare', () {
      expect(sample.amountAt(false), 100);
      expect(sample.amountAt(true), 150);
    });

    test('copyWith overrides fields without disturbing identity', () {
      final promoted = sample.copyWith(
        confidence: FareConfidence.verified,
        lastVerified: DateTime(2024, 9, 1),
      );
      expect(promoted.key, sample.key);
      expect(promoted.confidence, FareConfidence.verified);
      expect(promoted.lastVerified, DateTime(2024, 9, 1));
      expect(promoted.estimatedOffpeak, sample.estimatedOffpeak);
    });
  });
}