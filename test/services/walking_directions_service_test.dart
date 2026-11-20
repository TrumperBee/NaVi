import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/services/walking_directions_service.dart';

const _from = LatLng(-1.2864, 36.8237);
const _to = LatLng(-1.2900, 36.8400);

String _body(
  List<List<double>> coordinates, {
  double distance = 420,
  double duration = 300,
}) {
  return json.encode({
    'routes': [
      {
        'distance': distance,
        'duration': duration,
        'geometry': {
          'type': 'LineString',
          'coordinates': coordinates,
        },
      },
    ],
  });
}

void main() {
  test('parses a Directions response into road-following geometry', () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        _body([
          [36.8237, -1.2864],
          [36.8300, -1.2872],
          [36.8355, -1.2881],
          [36.8400, -1.2900],
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service =
        WalkingDirectionsService(accessToken: 'pk.test', client: client);
    final route = await service.route(_from, _to);

    expect(route.approximate, isFalse);
    expect(route.points.length, 4);
    expect(route.points.first.latitude, _from.latitude);
    expect(route.points.first.longitude, _from.longitude);
    expect(route.points.last.latitude, _to.latitude);
    expect(route.points.last.longitude, _to.longitude);
    expect(route.distanceMeters, 420);
    expect(route.durationSeconds, 300);

    // Walking profile, full GeoJSON overview.
    expect(requested!.path, contains('/directions/v5/mapbox/walking/'));
    expect(requested!.queryParameters['geometries'], 'geojson');
    expect(requested!.queryParameters['overview'], 'full');
    expect(requested!.queryParameters['access_token'], 'pk.test');
  });

  test('pins the exact start and end onto a snapped geometry', () async {
    final client = MockClient((_) async => http.Response(
          _body([
            // Snapped ~10 m off the requested endpoints.
            [36.8238, -1.2865],
            [36.8399, -1.2901],
          ]),
          200,
        ));

    final route = await WalkingDirectionsService(
      accessToken: 'pk.test',
      client: client,
    ).route(_from, _to);

    expect(route.points.length, 4);
    expect(route.points.first, _from);
    expect(route.points.last, _to);
  });

  test('reuses the cached route on a repeat call', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(
        _body([
          [36.8237, -1.2864],
          [36.8400, -1.2900],
        ]),
        200,
      );
    });

    final service =
        WalkingDirectionsService(accessToken: 'pk.test', client: client);
    final first = await service.route(_from, _to);
    final second = await service.route(_from, _to);

    expect(calls, 1);
    expect(service.cacheSize, 1);
    expect(identical(first, second), isTrue);

    // 4-decimal rounding means a ~10 m jitter still hits the same entry.
    await service.route(
      const LatLng(-1.28641, 36.82371),
      const LatLng(-1.29001, 36.84001),
    );
    expect(calls, 1);
  });

  test('a timeout falls back to a straight line marked approximate', () async {
    final client = MockClient(
      (_) async => throw TimeoutException('5s directions timeout'),
    );

    final route = await WalkingDirectionsService(
      accessToken: 'pk.test',
      client: client,
    ).route(_from, _to);

    expect(route.approximate, isTrue);
    expect(route.points, [_from, _to]);
    expect(route.distanceMeters, greaterThan(1500));
    expect(route.distanceMeters, lessThan(2200));
  });

  test('an empty token is reported once and falls back', () async {
    WalkingDirectionsService.resetMissingTokenLog();
    final service = WalkingDirectionsService(accessToken: '', client: MockClient(
      (_) async => fail('no request may be made without a token'),
    ));

    final first = await service.route(_from, _to);
    final second = await service.route(
      const LatLng(-1.2700, 36.8100),
      const LatLng(-1.2800, 36.8200),
    );

    expect(WalkingDirectionsService.missingTokenLogged, isTrue);
    expect(first.approximate, isTrue);
    expect(second.approximate, isTrue);
    expect(first.points, [_from, _to]);
  });
}
