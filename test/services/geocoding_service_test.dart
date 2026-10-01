import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:navi_app/services/geocoding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeocodingService.forward', () {
    test('biases to Nairobi via proximity, no bbox hard-filter', () async {
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(
          json.encode({
            'features': [
              {
                'center': [36.8219, -1.2921],
                'place_name': 'KICC, Nairobi CBD, Nairobi, Kenya',
                'relevance': 0.99,
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GeocodingService(
        accessToken: 'test-token',
        client: client,
      );
      final results = await service.geocodeMultiple('KICC', limit: 1);

      expect(results, hasLength(1));
      expect(results.first.placeName, 'KICC, Nairobi CBD, Nairobi, Kenya');
      expect(results.first.secondaryLine, 'Nairobi CBD, Nairobi, Kenya');
      expect(results.first.coordinate.latitude, closeTo(-1.2921, 0.0001));
      expect(results.first.coordinate.longitude, closeTo(36.8219, 0.0001));
      expect(requested!.queryParameters['proximity'], '36.8167,-1.2833');
      expect(requested!.queryParameters.containsKey('bbox'), isFalse);
      expect(requested!.queryParameters['types'],
          'place,address,poi,neighborhood');
      expect(requested!.queryParameters['access_token'], 'test-token');
    });

    test('geocode() throws noResults when features empty', () async {
      final client = MockClient(
          (_) async => http.Response(json.encode({'features': []}), 200));
      final service = GeocodingService(
        accessToken: 'test-token',
        client: client,
      );
      expect(
        () => service.geocode('nowhere street 99'),
        throwsA(isA<GeocodingError>()),
      );
    });

    test('multiple results are returned, ordered as given', () async {
      final client = MockClient((_) async => http.Response(
          json.encode({
            'features': [
              {
                'center': [36.82, -1.29],
                'place_name': 'Two Rivers, Nairobi',
                'relevance': 0.9,
              },
              {
                'center': [36.74, -1.22],
                'place_name': 'KICC, Nairobi',
                'relevance': 0.8,
              },
            ]
          }),
          200));
      final service = GeocodingService(
        accessToken: 't',
        client: client,
      );
      final results = await service.geocodeMultiple('place', limit: 5);
      expect(results, hasLength(2));
      expect(results.first.placeName, 'Two Rivers, Nairobi');
    });
  });

  group('GeocodingService.reverse', () {
    test('returns readable name for a coordinate', () async {
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(
          json.encode({
            'features': [
              {
                'center': [36.8167, -1.2833],
                'place_name': 'Kenyatta Avenue, Nairobi CBD, Nairobi, Kenya',
                'relevance': 0.98,
              }
            ],
          }),
          200,
        );
      });
      final service = GeocodingService(
        accessToken: 'test-token',
        client: client,
      );
      final result =
          await service.geocodeReverse(const LatLng(-1.283300, 36.816700));
      expect(result, isNotNull);
      expect(result!.placeName, contains('Kenyatta Avenue'));
      expect(requested!.path, contains('36.816700,-1.283300.json'));
    });

    test('returns null (never throws) on network failure', () async {
      final client = MockClient(
          (_) async => throw Exception('connection refused'));
      final service = GeocodingService(
        accessToken: 'test-token',
        client: client,
      );
      final result =
          await service.geocodeReverse(const LatLng(1.0, 1.0));
      expect(result, isNull);
    });
  });

  group('GeocodingService errors', () {
    test('throws typed network error when client throws', () async {
      final client = MockClient(
          (_) async => throw Exception('boom'));
      final service = GeocodingService(
        accessToken: 'test-token',
        client: client,
      );
      try {
        await service.geocodeMultiple('KICC');
        fail('expected GeocodingError');
      } on GeocodingError catch (e) {
        expect(e.type, GeocodingErrorType.network);
      }
    });

    test('throws rateLimited on 429', () async {
      final client = MockClient((_) async => http.Response('{}', 429));
      final service = GeocodingService(
        accessToken: 'test-token',
        client: client,
      );
      try {
        await service.geocodeMultiple('KICC');
        fail('expected GeocodingError');
      } on GeocodingError catch (e) {
        expect(e.type, GeocodingErrorType.rateLimited);
      }
    });
  });
}