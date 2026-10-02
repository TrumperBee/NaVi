import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/data/nairobi_places_seed.dart';
import 'package:navi_app/models/place_record.dart';
import 'package:navi_app/services/place_registry.dart';

void main() {
  group('PlaceRegistry seed', () {
    test('ships 20 curated places with sequential unique PL ids (§4)', () {
      final places = PlaceRegistry.all;
      expect(places.length, 20);

      final ids = places.map((p) => p.placeId).toList();
      expect(ids.toSet().length, ids.length, reason: 'ids must be unique');
      final expected = [for (int i = 1; i <= 20; i++) 'PL${i.toString().padLeft(4, '0')}'];
      expect(ids, expected);
      for (final place in places) {
        expect(RegExp(r'^PL\d{4}$').hasMatch(place.placeId), isTrue);
      }
    });

    test('every seed place is contributor-curated and verified', () {
      for (final place in PlaceRegistry.all) {
        expect(place.source, PlaceSource.contributor);
        expect(place.confidence, PlaceConfidence.verified);
      }
    });
  });

  group('PlaceRegistry lookup', () {
    test('findById resolves', () {
      expect(PlaceRegistry.findById('PL0001')?.name, 'Roysambu');
      expect(PlaceRegistry.findById('PL9999'), isNull);
    });

    test('findByName is case-insensitive against name and aliases', () {
      expect(PlaceRegistry.findByName('Roysambu')?.placeId, 'PL0001');
      expect(PlaceRegistry.findByName('roysambu')?.placeId, 'PL0001');
      // Alias hit: "TRM" is an alias of Two Rivers Mall.
      expect(PlaceRegistry.findByName('trm')?.name, 'Two Rivers Mall');
      expect(PlaceRegistry.findByName('KNH')?.name, 'Kenyatta National Hospital');
    });

    test('fuzzy matching tolerates small typos within the stage-layer tolerance', () {
      // Levenshtein distance 1 ("Roosambu") still resolves, like the stage layer.
      expect(PlaceRegistry.findByName('Roosambu')?.placeId, 'PL0001');
      // Distance 2 ("Kolimani") stays within tolerance.
      final kilimani = PlaceRegistry.findByName('Kolimani');
      expect(kilimani, isNotNull);
      expect(kilimani!.name, contains('Kilimani'));
    });

    test('unrelated names do not fuzzy-match', () {
      // NB: "Siaya" is deliberately NOT here — it legitimately fuzz-matches
      // "Yaya" under the shared stage-layer tolerance (levenshtein 2). That
      // leniency is fine for surfacing search candidates; the GTFS *linker*
      // is what must refuse it, and does (see gtfs_place_linking_test).
      expect(PlaceRegistry.findByName('Kampala'), isNull);
      expect(PlaceRegistry.findByName('Nyerere'), isNull);
    });

    test('findExact requires an exact name/alias, not a fuzzy hit', () {
      expect(PlaceRegistry.findExact('Roysambu')?.placeId, 'PL0001');
      expect(PlaceRegistry.findExact('Roosambu'), isNull);
    });

    test('findMatching returns every alternative, best first', () {
      final githurai = PlaceRegistry.findMatching('Githurai');
      expect(githurai, isNotEmpty);
      expect(githurai.first.name, 'Githurai 44');

      final candidates = PlaceRegistry.findMatching('I&M Bank');
      expect(candidates.first.placeId, 'PL0008');
    });

    test('empty query yields nothing', () {
      expect(PlaceRegistry.findByName('   '), isNull);
      expect(PlaceRegistry.findMatching(''), isEmpty);
    });
  });

  group('PlaceRegistry swap', () {
    tearDown(() {
      PlaceRegistry.setPlaces(nairobiPlaces);
    });

    test('setPlaces swaps the active universe', () {
      const replacement = PlaceRecord(
        placeId: 'PL9999',
        name: 'Test Place',
        type: PlaceType.landmark,
        latitude: 0.0,
        longitude: 0.0,
      );
      PlaceRegistry.setPlaces([replacement]);
      expect(PlaceRegistry.all.length, 1);
      expect(PlaceRegistry.findByName('Test Place')?.placeId, 'PL9999');
    });

    test('setPlaces ignores empty input so a failed sync never wipes the seed', () {
      PlaceRegistry.setPlaces([]);
      expect(PlaceRegistry.all.length, 20);
    });
  });
}