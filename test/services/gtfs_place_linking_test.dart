import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/models/place_record.dart';
import 'package:navi_app/models/stage_record.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/services/gtfs_import_service.dart';
import 'package:navi_app/services/place_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GtfsImportResult result;

  setUpAll(() async {
    result = await GtfsImportService.parseBundledGtfs();
  });

  StageRecord stage(String id, String name, double lat, double lng) {
    return StageRecord(
      stageId: id,
      stageName: name,
      latitude: lat,
      longitude: lng,
      roadName: '',
      area: '',
      county: 'Nairobi',
      routesServed: const [],
    );
  }

  PlaceRecord odeon() => PlaceRegistry.findById('PL0011')!;

  group('GTFS place linking (spec §1.2)', () {
    test('links only unambiguous near-name + proximity stops', () {
      // Seven seeded places own an exactly-matching lone stop.
      expect(result.placeLinks, isNotEmpty);
      expect(result.placeLinks.length, 7);
      expect(result.placeLinks['PL0004'], 'university_of_nairobi');
      expect(result.placeLinks['PL0010'], 'kencom-ambassadeur');
      expect(result.placeLinks['PL0011'], 'odeon');
      expect(result.placeLinks['PL0012'], 'commercial_1');
    });

    test('every link resolves and writes through to the stage record', () {
      final stagesById = {for (final s in result.stages) s.stageId: s};
      for (final entry in result.placeLinks.entries) {
        final linked = stagesById[entry.value];
        expect(linked, isNotNull, reason: '${entry.key} -> ${entry.value}');
        expect(linked!.placeId, entry.key);
      }
    });

    test('ambiguous and implausible links are refused', () {
      // "Roysambu" maps to Roysambu, Roysambu Footbridge and Roysambu
      // Terminus near one another: no single stop owns it.
      expect(result.placeLinks.containsKey('PL0001'), isFalse);
      // "Yaya" must NOT fuzzy-match the "Siaya" stop in the bundle.
      expect(result.placeLinks.containsKey('PL0009'), isFalse);
    });

    test('only a small minority of the 2,771 stops carry a place id', () {
      final linked = result.stages.where((s) => s.placeId != null).length;
      expect(linked, result.placeLinks.length);
      expect(result.stages.where((s) => s.placeId == null).length,
          greaterThanOrEqualTo(2700));
    });

    test('each linked stage is literally named after its place (no fuzzy luck)', () {
      for (final entry in result.placeLinks.entries) {
        final place = PlaceRegistry.findById(entry.key);
        expect(place, isNotNull, reason: '${entry.key} must exist');
        final stage = result.stages.firstWhere((s) => s.stageId == entry.value);
        final names = {
          place!.name.toLowerCase(),
          ...place.aliases.map((a) => a.toLowerCase()),
        };
        expect(_strongNameMatch(stage.stageName.toLowerCase(), names), isTrue,
            reason: '"${stage.stageName}" must be named after $place');
      }
    });
  });

  group('linkStagesToPlaces purity', () {
    test('unambiguous single stop links; stage carries placeId', () {
      final o = odeon();
      final stages = [
        stage('odeon_1', 'Odeon', o.latitude, o.longitude),
        stage('railways', 'Railways Club', -1.2860, 36.8260),
      ];

      final linked = GtfsImportService.linkStagesToPlaces(stages);
      expect(linked.links.length, 1);
      expect(linked.links.single.placeId, 'PL0011');
      expect(linked.links.single.stageId, 'odeon_1');
      expect(linked.stages.first.placeId, 'PL0011');
      expect(linked.stages.last.placeId, isNull);
    });

    test('two nearby same-named stops are ambiguous and both stay unlinked', () {
      final o = odeon();
      final stages = [
        stage('odeon_1', 'Odeon', o.latitude, o.longitude),
        stage('odeon_2', 'Odeon', o.latitude + 0.002, o.longitude),
      ];

      final linked = GtfsImportService.linkStagesToPlaces(stages);
      expect(linked.links, isEmpty);
      expect(linked.stages.every((s) => s.placeId == null), isTrue);
    });

    test('a right-named but far-away stop is not a link', () {
      final stages = [stage('odeon_far', 'Odeon', -1.2000, 37.0000)];

      final linked = GtfsImportService.linkStagesToPlaces(stages);
      expect(linked.links, isEmpty);
      expect(linked.stages.single.placeId, isNull);
    });

    test('a fuzzy lookalike like Siaya vs Yaya never links', () {
      final yaya = PlaceRegistry.findById('PL0009')!;
      final stages = [
        stage('siaya', 'Siaya', yaya.latitude, yaya.longitude),
      ];

      final linked = GtfsImportService.linkStagesToPlaces(stages);
      expect(linked.links, isEmpty);
    });
  });

  group('placeId cache persistence (additive, backward compatible)', () {
    test('StageModel -> JSON -> StageModel keeps placeId', () {
      final model = StageModel(
        id: 'odeon',
        name: 'Odeon',
        lat: -1.2828,
        lng: 36.8247,
        corridor: 'cbd',
        routes: const ['34'],
        placeId: 'PL0011',
      );

      final revived = StageModel.fromMap(
        jsonDecode(jsonEncode(model.toMap())) as Map<String, dynamic>,
        'odeon',
      );
      expect(revived.placeId, 'PL0011');
    });

    test('a cached row written before placeId still decodes (placeId null)', () {
      final old = StageModel.fromMap({
        'id': 'roysambu',
        'name': 'Roysambu',
        'lat': -1.2333,
        'lng': 36.88,
        'corridor': 'thika_road',
        'routes': <String>['44'],
      }, 'roysambu');
      expect(old.placeId, isNull);
    });

    test('StageRecord round-trips placeId and tolerates its absence', () {
      final withPlace = stage('odeon', 'Odeon', -1.28, 36.82).copyWith(placeId: 'PL0011');
      expect(StageRecord.fromMap(withPlace.toMap(), 'odeon').placeId, 'PL0011');

      final withoutPlace = StageRecord.fromMap(
        {'stage_id': 'x', 'stage_name': 'X'}, 'x');
      expect(withoutPlace.placeId, isNull);
    });
  });
}

/// Same strong-name rule the linker uses: whole-name equality or an exact
/// token sequence ("university of nairobi" ⊂ a name/alias; "yaya" NOT ⊂
/// "siaya").
bool _strongNameMatch(String name, Set<String> placeNames) {
  final tokens = name
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.length >= 3)
      .toList();
  for (final placeName in placeNames) {
    if (placeName.isEmpty || placeName.length < 3) continue;
    if (name == placeName) return true;
    final parts = placeName.split(' ');
    if (parts.length == 1) {
      if (tokens.contains(placeName)) return true;
    } else {
      for (int i = 0; i + parts.length <= tokens.length; i++) {
        if (tokens.sublist(i, i + parts.length).join(' ') == placeName) {
          return true;
        }
      }
    }
  }
  return false;
}