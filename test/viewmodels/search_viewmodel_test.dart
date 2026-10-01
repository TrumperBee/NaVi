import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:navi_app/services/geocoding_service.dart';
import 'package:navi_app/viewmodels/search_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SearchViewModel buildViewModel(http.Client client, {int debounceMs = 1}) {
    return SearchViewModel(
      geocodingService: GeocodingService(accessToken: 'test-token', client: client),
      debounceMs: debounceMs,
      cacheSize: 10,
    );
  }

  group('SearchViewModel.query', () {
    test('empty query clears results and error', () async {
      final vm = buildViewModel(MockClient((_) async => http.Response('{}', 200)));
      vm.updateQuery('KICC');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      vm.updateQuery('   ');
      expect(vm.results, isEmpty);
      expect(vm.error, isNull);
      expect(vm.isLoading, isFalse);
      vm.dispose();
    });

    test('geocodes multiple Mapbox results into resolved entries', () async {
      final client = MockClient((_) async => http.Response(
          json.encode({
            'features': [
              {
                'center': [36.8219, -1.2921],
                'place_name': 'KICC, Nairobi CBD, Nairobi, Kenya',
                'relevance': 0.99,
              },
              {
                'center': [36.7800, -1.2700],
                'place_name': 'Yaya Centre, Hurlingham, Nairobi, Kenya',
                'relevance': 0.85,
              },
            ]
          }),
          200));
      final vm = buildViewModel(client);
      vm.updateQuery('KICC');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.isLoading, isFalse);
      expect(vm.results, isNotEmpty);
      expect(vm.error, isNull);
      final labels = vm.results.map((r) => r.resolvedLabel).toList();
      expect(labels.any((l) => l.contains('KICC')), isTrue);
      // Corridor resolution keeps secondary line & distance from user.
      final withSecondary =
          vm.results.where((r) => r.secondaryLine != null).toList();
      expect(withSecondary, isNotEmpty);
      expect(withSecondary.first.secondaryLine, isNot(contains('KICC')));
      vm.dispose();
    });

    test('empty Mapbox response yields friendly no-result error', () async {
      final client =
          MockClient((_) async => http.Response(json.encode({'features': []}), 200));
      final vm = buildViewModel(client);
      vm.updateQuery('definitely-not-a-kenyan-place-xyz');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.results, isEmpty);
      expect(vm.error, contains('No results found'));
      expect(vm.error, contains('definitely-not-a-kenyan-place-xyz'));
      vm.dispose();
    });

    test('network failure keeps local stage matches and notes it', () async {
      final client = MockClient((_) async => throw Exception('offline'));
      final vm = buildViewModel(client);
      // "Westlands" hits the local stage matcher ("Westlands Stage").
      vm.updateQuery('Westlands');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.results, isNotEmpty);

      // Give the retry/backoff (3 attempts ≈ 3s) time to surface the offline
      // note while the local matches stay on screen.
      await Future<void>.delayed(const Duration(milliseconds: 3600));
      expect(vm.results, isNotEmpty);
      expect(vm.error, isNotNull);
      expect(vm.error, contains('Offline'));
      vm.dispose();
    });

    test('network failure with no local match shows no-network error', () async {
      final client = MockClient((_) async => throw Exception('offline'));
      final vm = buildViewModel(client);
      vm.updateQuery('xyzzy notreal stagename');
      await Future<void>.delayed(const Duration(milliseconds: 3600));
      expect(vm.results, isEmpty);
      expect(vm.error, contains('No network'));
      vm.dispose();
    });

    test('caches results and reuses them on repeat query', () async {
      var requestCount = 0;
      final client = MockClient((_) async {
        requestCount++;
        return http.Response(
            json.encode({
              'features': [
                {
                  'center': [36.8167, -1.2833],
                  'place_name': 'Two Rivers, Nairobi',
                  'relevance': 0.9,
                }
              ]
            }),
            200);
      });
      final vm = buildViewModel(client);
      vm.updateQuery('Two Rivers');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final firstCount = requestCount;
      expect(firstCount, greaterThanOrEqualTo(1));

      vm.updateQuery('Two Rivers'); // cached -> no extra request
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(requestCount, firstCount);
      vm.dispose();
    });
  });
}