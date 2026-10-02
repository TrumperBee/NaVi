import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/models/place_record.dart';

void main() {
  group('PlaceRecord serialization', () {
    test('round-trips every field through toMap/fromMap', () {
      const place = PlaceRecord(
        placeId: 'PL0001',
        name: 'Roysambu',
        aliases: ['Roysambu Estate'],
        type: PlaceType.area,
        latitude: -1.2333,
        longitude: 36.8800,
        source: PlaceSource.contributor,
        confidence: PlaceConfidence.verified,
      );

      final hydrated = PlaceRecord.fromMap(place.toMap());

      expect(hydrated.placeId, place.placeId);
      expect(hydrated.name, place.name);
      expect(hydrated.aliases, place.aliases);
      expect(hydrated.type, place.type);
      expect(hydrated.latitude, place.latitude);
      expect(hydrated.longitude, place.longitude);
      expect(hydrated.source, place.source);
      expect(hydrated.confidence, place.confidence);
    });

    test('parses legacy lat/lng keys', () {
      final place = PlaceRecord.fromMap({
        'place_id': 'PL0001',
        'name': 'Roysambu',
        'lat': -1.2333,
        'lng': 36.88,
        'type': 'area',
      });

      expect(place.latitude, -1.2333);
      expect(place.longitude, closeTo(36.88, 0.001));
      expect(place.type, PlaceType.area);
      expect(place.source, PlaceSource.contributor);
      expect(place.confidence, PlaceConfidence.unverified);
      expect(place.aliases, isEmpty);
    });

    test('defaults when optional/missing fields absent', () {
      final place = PlaceRecord.fromMap({'place_id': 'PL0002', 'name': 'TRM'});
      expect(place.type, PlaceType.area);
      expect(place.source, PlaceSource.contributor);
      expect(place.confidence, PlaceConfidence.unverified);
      expect(place.latitude, 0.0);
      expect(place.longitude, 0.0);
    });

    test('parses every enum name and falls back on unknown strings', () {
      final place = PlaceRecord.fromMap({
        ...const PlaceRecord(
          placeId: 'PL0003',
          name: 'KNH',
          latitude: -1.2995,
          longitude: 36.8148,
          type: PlaceType.institution,
          source: PlaceSource.gtfsImport,
          confidence: PlaceConfidence.disputed,
        ).toMap(),
        'type': 'building',
        'source': 'mapboxGeocode',
        'confidence': 'verified',
      });
      expect(place.type, PlaceType.building);
      expect(place.source, PlaceSource.mapboxGeocode);
      expect(place.confidence, PlaceConfidence.verified);

      final unknown = PlaceRecord.fromMap({
        'place_id': 'PL0004',
        'name': 'x',
        'type': 'not-a-kind',
        'source': 'not-a-source',
        'confidence': 'not-a-level',
      });
      expect(unknown.type, PlaceType.area);
      expect(unknown.source, PlaceSource.contributor);
      expect(unknown.confidence, PlaceConfidence.unverified);
    });

    test('fromMap accepts already-parsed enum values', () {
      final place = PlaceRecord.fromMap({
        'place_id': 'PL0005',
        'name': 'UoN',
        'type': PlaceType.institution,
        'source': PlaceSource.contributor,
        'confidence': PlaceConfidence.verified,
      });
      expect(place.type, PlaceType.institution);
      expect(place.source, PlaceSource.contributor);
      expect(place.confidence, PlaceConfidence.verified);
    });
  });
}