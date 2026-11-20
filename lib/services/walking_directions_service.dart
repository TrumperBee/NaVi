import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'mapbox_config.dart';

/// One walking leg resolved against the real road network.
class WalkingRoute {
  /// Road-following geometry. Starts at the exact origin and ends at the exact
  /// destination so the drawn line touches the user's puck and the stage pin.
  final List<LatLng> points;

  /// Road distance in metres, as reported by the directions API.
  final double distanceMeters;

  /// Estimated walking time in seconds.
  final double durationSeconds;

  /// True when the geometry is the straight-line fallback (no token, network
  /// failure, timeout or a malformed response) rather than a real route.
  final bool approximate;

  const WalkingRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.approximate,
  });
}

/// Road-following walking geometry from the Mapbox Directions API.
///
/// Replaces the straight-chord walk legs and the old OSRM pass: every walking
/// leg (to the first stage, transfer walks, final walk) asks this service for
/// the real pavement route.
///
/// Failure policy: never throw, never swallow. Every failure is logged with
/// its reason and the leg falls back to a straight line marked
/// [WalkingRoute.approximate], which the Route Preview sheet and the Active
/// Navigation panel surface as "Approximate route".
class WalkingDirectionsService {
  /// Same Mapbox host as geocoding/directions elsewhere in the app.
  static String get baseUrl => '${MapboxConfig.directionsBaseUrl}/walking';

  /// The directions call must never hold the Route Preview hostage.
  static const Duration requestTimeout = Duration(seconds: 5);

  /// Mapbox walking speed fallback when the API could not answer (matches the
  /// builder's 1.4 m/s assumption).
  static const double fallbackSpeedMs = 1.4;

  /// One log line per process for a missing token - a 6-leg journey must not
  /// print the same warning six times.
  static bool _missingTokenLogged = false;

  /// Test hook: true once the missing-token warning has been emitted.
  @visibleForTesting
  static bool get missingTokenLogged => _missingTokenLogged;

  /// Test hook: reset the one-shot warning flag.
  @visibleForTesting
  static void resetMissingTokenLog() => _missingTokenLogged = false;

  final String? _accessToken;
  final http.Client _client;
  final Map<String, WalkingRoute> _cache = {};

  WalkingDirectionsService({String? accessToken, http.Client? client})
      : _accessToken = accessToken,
        _client = client ?? http.Client();

  /// Test hook: how many cache entries are held.
  @visibleForTesting
  int get cacheSize => _cache.length;

  @visibleForTesting
  void clearCache() => _cache.clear();

  /// Resolves the walking route between two points.
  ///
  /// Cached by start/end rounded to 4 decimals (~11 m), so dragging a map or
  /// re-opening the same preview does not spend another request. Only real
  /// answers are cached: a fallback is retried next time, because the network
  /// may be back.
  Future<WalkingRoute> route(LatLng from, LatLng to) async {
    final key = _cacheKey(from, to);
    final cached = _cache[key];
    if (cached != null) return cached;

    // A leg shorter than a metre has no road to follow; skip the request.
    final direct = _distanceBetween(from, to);
    if (direct < 1.0) {
      return WalkingRoute(
        points: [from, to],
        distanceMeters: direct,
        durationSeconds: direct / fallbackSpeedMs,
        approximate: false,
      );
    }

    final token = await _token();
    if (token.isEmpty) {
      _logMissingToken();
      return _straightLine(from, to);
    }

    final url = Uri.parse(
      '$baseUrl/${_coord(from)};${_coord(to)}'
      '?geometries=geojson'
      '&overview=full'
      '&access_token=$token',
    );

    try {
      final response = await _client.get(url).timeout(requestTimeout);
      if (response.statusCode != 200) {
        _logFailure(from, to, 'HTTP ${response.statusCode}');
        return _straightLine(from, to);
      }
      final parsed = _parse(response.body, from, to);
      if (parsed == null) {
        _logFailure(from, to, 'unparseable response');
        return _straightLine(from, to);
      }
      _cache[key] = parsed;
      return parsed;
    } on TimeoutException {
      _logFailure(from, to, 'timed out after ${requestTimeout.inSeconds}s');
      return _straightLine(from, to);
    } catch (e) {
      _logFailure(from, to, '$e');
      return _straightLine(from, to);
    }
  }

  String? _resolvedToken;

  /// `flutter test` exports FLUTTER_TEST. Without this guard the builder's
  /// default service would resolve the real token from the local secrets file
  /// and make live Directions calls from unit tests. An explicitly injected
  /// token (the service's own tests) always wins, so parsing, caching and
  /// timeout behaviour stay fully testable.
  static bool get _isTestProcess =>
      Platform.environment['FLUTTER_TEST'] == 'true';

  Future<String> _token() async {
    final override = _accessToken;
    if (override != null) return override;
    if (_isTestProcess) return '';
    return _resolvedToken ??= MapboxConfig.accessToken;
  }

  /// Parses a Directions API body into a [WalkingRoute]. Returns null when the
  /// payload has no usable route geometry.
  WalkingRoute? _parse(String body, LatLng from, LatLng to) {
    final dynamic decoded;
    try {
      decoded = json.decode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final first = routes.first;
    if (first is! Map<String, dynamic>) return null;

    final geometry = first['geometry'];
    if (geometry is! Map<String, dynamic>) return null;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;

    final points = <LatLng>[];
    for (final raw in coordinates) {
      if (raw is! List || raw.length < 2) continue;
      final lng = (raw[0] as num).toDouble();
      final lat = (raw[1] as num).toDouble();
      points.add(LatLng(lat, lng));
    }
    if (points.length < 2) return null;

    // The API usually returns the requested endpoints, but a snapped start or
    // end would leave a visible gap to the puck / pin. Pin them explicitly.
    final pinned = _pinEndpoints(points, from, to);

    final distance = (first['distance'] as num?)?.toDouble() ??
        _pathLength(pinned);
    final duration = (first['duration'] as num?)?.toDouble() ??
        (distance / fallbackSpeedMs);

    return WalkingRoute(
      points: pinned,
      distanceMeters: distance,
      durationSeconds: duration,
      approximate: false,
    );
  }

  List<LatLng> _pinEndpoints(List<LatLng> points, LatLng from, LatLng to) {
    final result = List<LatLng>.of(points);
    if (_samePoint(result.first, from)) {
      result[0] = from;
    } else {
      result.insert(0, from);
    }
    if (_samePoint(result.last, to)) {
      result[result.length - 1] = to;
    } else {
      result.add(to);
    }
    return result;
  }

  WalkingRoute _straightLine(LatLng from, LatLng to) {
    final distance = _distanceBetween(from, to);
    return WalkingRoute(
      points: [from, to],
      distanceMeters: distance,
      durationSeconds: distance / fallbackSpeedMs,
      approximate: true,
    );
  }

  void _logMissingToken() {
    if (_missingTokenLogged) return;
    _missingTokenLogged = true;
    debugPrint('[WALK] MAPBOX_TOKEN missing - walking legs fall back to '
        'straight lines marked "Approximate route"');
  }

  void _logFailure(LatLng from, LatLng to, String reason) {
    debugPrint('[WALK] directions failed (${_coord(from)} -> ${_coord(to)}): '
        '$reason - falling back to a straight line');
  }

  static String _cacheKey(LatLng from, LatLng to) =>
      '${_round4(from)}|${_round4(to)}';

  static String _round4(LatLng p) =>
      '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';

  static String _coord(LatLng p) =>
      '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}';

  /// True when two coordinates describe the same place at ~1 m resolution.
  static bool _samePoint(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < 1e-5 &&
      (a.longitude - b.longitude).abs() < 1e-5;

  static double _pathLength(List<LatLng> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _distanceBetween(points[i - 1], points[i]);
    }
    return total;
  }

  static double _distanceBetween(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    const degToRad = math.pi / 180;
    final dLat = (b.latitude - a.latitude) * degToRad;
    final dLng = (b.longitude - a.longitude) * degToRad;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitude * degToRad) *
            math.cos(b.latitude * degToRad) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}
