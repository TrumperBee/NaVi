import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:navi_app/services/mapbox_config.dart';

class GeocodingResult {
  final LatLng coordinate;
  final String placeName;

  /// Short secondary line: the region/area suffix of the Mapbox place_name
  /// (e.g. "Westlands, Nairobi, Kenya" for a poi). Null when unavailable.
  final String? secondaryLine;
  final String? relevance;

  const GeocodingResult({
    required this.coordinate,
    required this.placeName,
    this.secondaryLine,
    this.relevance,
  });

  factory GeocodingResult.fromMapbox(Map<String, dynamic> json) {
    final center = json['center'] as List<dynamic>?;
    if (center == null || center.length != 2) {
      throw const FormatException('Invalid center in Mapbox response');
    }
    final placeName = json['place_name'] as String? ?? '';
    return GeocodingResult(
      coordinate: LatLng(center[1].toDouble(), center[0].toDouble()),
      placeName: placeName,
      secondaryLine: _secondaryLineFrom(placeName),
      relevance: json['relevance']?.toString(),
    );
  }

  /// The Mapbox `place_name` is "Venue, SubArea, Area, Country". The primary
  /// name is the part before the first comma; everything after it reads as a
  /// short "area / context" line without repeating the venue name.
  static String? _secondaryLineFrom(String placeName) {
    if (placeName.isEmpty) return null;
    final parts = placeName
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length <= 1) return null;
    return parts.sublist(1).join(', ');
  }
}

class GeocodingError implements Exception {
  final String message;
  final GeocodingErrorType type;

  const GeocodingError(this.message, this.type);

  @override
  String toString() => 'GeocodingError($type): $message';
}

enum GeocodingErrorType {
  network,
  timeout,
  noResults,
  invalidResponse,
  rateLimited,
}

class GeocodingService {
  static const String _baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

  /// Soft bias point (Nairobi CBD). Mapbox `proximity` RANKS nearby results
  /// higher without hard-restricting, which is exactly what the product wants:
  /// real edge-of-metro places still resolve even if they fall outside the
  /// metro box, but Nairobi results are preferred. (A `bbox` param would be a
  /// hard filter and drop those places entirely.)
  static const String _nairobiProximity = '36.8167,-1.2833';
  static const int _timeoutSeconds = 5;
  static const int _maxRetries = 3;

  final String _accessToken;
  final http.Client _client;

  GeocodingService({
    String? accessToken,
    http.Client? client,
  })  : _accessToken = accessToken ?? MapboxConfig.accessToken,
        _client = client ?? http.Client();

  Future<GeocodingResult> geocode(String query) async {
    final results = await geocodeMultiple(query, limit: 1);
    if (results.isEmpty) {
      throw const GeocodingError('No results found', GeocodingErrorType.noResults);
    }
    return results.first;
  }

  /// Forward-geocodes [query] against Mapbox, biased to Nairobi but never
  /// hard-restricted to the metro box. Returns up to [limit] results.
  Future<List<GeocodingResult>> geocodeMultiple(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) return [];

    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse(
      '$_baseUrl/$encodedQuery.json'
      '?proximity=$_nairobiProximity'
      '&limit=$limit'
      '&access_token=$_accessToken'
      '&autocomplete=true'
      '&language=en'
      '&types=place,address,poi,neighborhood',
    );

    final features = await _requestFeatures(url);
    return features
        .map((f) => GeocodingResult.fromMapbox(f as Map<String, dynamic>))
        .toList();
  }

  /// Reverse-geocodes a coordinate to a readable place name, e.g. for the
  /// "Set Home to my current location" flow. Returns null rather than throwing
  /// so callers can degrade gracefully to a platform label.
  Future<GeocodingResult?> geocodeReverse(LatLng coordinate,
      {int limit = 1}) async {
    final lng = coordinate.longitude.toStringAsFixed(6);
    final lat = coordinate.latitude.toStringAsFixed(6);
    final url = Uri.parse(
      '$_baseUrl/$lng,$lat.json'
      '?access_token=$_accessToken'
      '&language=en'
      '&limit=$limit'
      '&types=place,address,poi,neighborhood',
    );

    try {
      final features = await _requestFeatures(url);
      if (features.isEmpty) return null;
      return GeocodingResult.fromMapbox(features.first as Map<String, dynamic>);
    } on GeocodingError {
      return null;
    }
  }

  /// Shared Mapbox GET with retry/backoff. Throws [GeocodingError] with a
  /// typed cause on network / timeout / rate-limit / bad-response; returns the
  /// parsed `features` array (possibly empty) on a clean 200.
  Future<List<dynamic>> _requestFeatures(Uri url) async {
    http.Response? lastResponse;
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        lastResponse = await _client
            .get(url, headers: {'User-Agent': 'NaViNairobi/1.0'})
            .timeout(Duration(seconds: _timeoutSeconds));

        if (lastResponse.statusCode == 200) {
          break;
        } else if (lastResponse.statusCode == 429) {
          throw const GeocodingError('Rate limited', GeocodingErrorType.rateLimited);
        }

        if (attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: attempt));
        }
      } on TimeoutException {
        if (attempt >= _maxRetries) {
          throw const GeocodingError('Request timeout', GeocodingErrorType.timeout);
        }
        await Future.delayed(Duration(seconds: attempt));
      } on GeocodingError {
        rethrow;
      } catch (e) {
        if (attempt >= _maxRetries) {
          throw GeocodingError('Network error: $e', GeocodingErrorType.network);
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    if (lastResponse == null || lastResponse.statusCode != 200) {
      final status = lastResponse?.statusCode ?? 'no response';
      if (status == 429) {
        throw const GeocodingError('Rate limited', GeocodingErrorType.rateLimited);
      }
      throw GeocodingError('Geocoding failed with status $status', GeocodingErrorType.invalidResponse);
    }

    final data = json.decode(lastResponse.body) as Map<String, dynamic>;
    return data['features'] as List<dynamic>? ?? [];
  }

  void dispose() {
    _client.close();
  }
}