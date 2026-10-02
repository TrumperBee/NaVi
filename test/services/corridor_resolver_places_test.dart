import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/search_result.dart';
import 'package:navi_app/services/corridor_resolver.dart';
import 'package:navi_app/services/geocoding_service.dart';
import 'package:navi_app/services/place_registry.dart';
import 'package:navi_app/viewmodels/search_viewmodel.dart';

void main() {
  GeocodingResult geocodeFor(double lat, double lng, String name) {
    return GeocodingResult(
      coordinate: LatLng(lat, lng),
      placeName: name,
    );
  }

  group('place lookup layer (§3 first layer)', () {
    test('findExactPlaceMatch resolves a name or alias case-insensitively', () {
      expect(CorridorResolver.findExactPlaceMatch('Roysambu')?.placeId, 'PL0001');
      expect(CorridorResolver.findExactPlaceMatch('trm')?.name, 'Two Rivers Mall');
      expect(CorridorResolver.findExactPlaceMatch('Mwiki'), isNull);
    });

    test('findPlacesByName returns every alternative', () {
      final roysambu = CorridorResolver.findPlacesByName('Roysambu');
      expect(roysambu.map((p) => p.placeId), contains('PL0001'));
    });
  });

  group('place → transit resolution', () {
    test('a landmark-only place gets boarding context from the nearest stage '
        'on the nearest corridor', () {
      final im = PlaceRegistry.findByName('I&M Bank Tower')!;
      final result = CorridorResolver.resolvePlace(im, query: 'I&M Bank Tower');

      expect(result.source, SearchResultSource.localPlace);
      expect(result.resolvedLabel, 'I&M Bank Tower');
      expect(result.matchedCorridorName, 'Mombasa Road');
      expect(result.nearestStageName, 'Nyayo Stadium Stage');
      expect(result.routeNumbers, isNotEmpty);
      expect(result.distanceToStageMeters, lessThan(1500));
    });

    test('a place off every corridor reports local no-transit, not a crash', () {
      final roysambu = PlaceRegistry.findByName('Roysambu')!;
      final result = CorridorResolver.resolvePlace(roysambu, query: 'Roysambu');
      expect(result.resolvedLabel, 'Roysambu');
      expect(result.source, SearchResultSource.localPlace);
      expect(result.routeNumbers, isEmpty);
    });

    test('§3 order: an exact place outranks the stage and geocoding in resolve', () {
      final result = CorridorResolver.resolve(
        'I&M Bank Tower',
        geocodeFor(-1.2850, 36.8200, 'I&M Bank'),
      );
      expect(result.source, SearchResultSource.localPlace);
      expect(result.nearestStageName, 'Nyayo Stadium Stage');

      final kencom = CorridorResolver.resolve(
        'Kencom',
        geocodeFor(-1.2833, 36.8167, 'Kencom'),
      );
      expect(kencom.source, SearchResultSource.localPlace);
      expect(kencom.resolvedLabel, 'Kencom');
      expect(kencom.nearestStageName, 'Kencom Bus Station');
    });

    test('stage layer still resolves when no place matches', () {
      final result = CorridorResolver.resolve(
        'Mwiki',
        geocodeFor(-1.2120, 36.8880, 'Mwiki'),
      );
      expect(result.source, SearchResultSource.exactStage);
      expect(result.resolvedLabel, contains('Mwiki'));
      expect(result.routeNumbers, isNotEmpty);
    });
  });

  group('SearchViewModel local search surfaces place + stage distinctly', () {
    test('"Roysambu" returns the area place and the Roysambu Stage stop', () {
      final vm = SearchViewModel(debounceMs: 400);
      addTearDown(vm.dispose);

      vm.updateQuery('Roysambu');

      final labels = vm.results.map((r) => r.resolvedLabel).toList();
      expect(labels, contains('Roysambu'));
      expect(labels, contains('Roysambu Stage'));

      // §3: the place sits above the stage in the merged list.
      expect(vm.results.first.resolvedLabel, 'Roysambu');
      expect(vm.results.first.source, SearchResultSource.localPlace);
      expect(vm.results.map((r) => r.source),
          contains(SearchResultSource.exactStage));
      expect(vm.searchSource, 'Local places + stage matches');
    });

    test('a landmark-only query still returns a local place result first', () {
      final vm = SearchViewModel(debounceMs: 400);
      addTearDown(vm.dispose);

      vm.updateQuery('Kenyatta National Hospital');
      expect(vm.results, isNotEmpty);
      expect(vm.results.first.resolvedLabel, 'Kenyatta National Hospital');
      expect(vm.results.first.source, SearchResultSource.localPlace);
    });
  });
}