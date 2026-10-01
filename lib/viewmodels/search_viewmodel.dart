import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:navi_app/models/search_result.dart';
import 'package:navi_app/services/geocoding_service.dart';
import 'package:navi_app/services/corridor_resolver.dart';

class SearchViewModel extends ChangeNotifier {
  final GeocodingService _geocodingService;
  final int _debounceMs;
  final int _cacheSize;

  String _searchQuery = '';
  bool _isLoading = false;
  List<SearchResult> _results = [];
  String? _error;
  String? _searchSource;

  final LinkedHashMap<String, List<SearchResult>> _cache =
      LinkedHashMap<String, List<SearchResult>>();
  Timer? _debounceTimer;

  SearchViewModel({
    GeocodingService? geocodingService,
    int debounceMs = 400,
    int cacheSize = 20,
  })  : _geocodingService = geocodingService ?? GeocodingService(),
        _debounceMs = debounceMs,
        _cacheSize = cacheSize;

  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  List<SearchResult> get results => List.unmodifiable(_results);
  String? get error => _error;
  String? get searchSource => _searchSource;

  /// Exposed so consumers (e.g. the saved-destination dialog) can reverse
  /// geocode with the same Mapbox client and token.
  GeocodingService get geocodingService => _geocodingService;

  void updateQuery(String query) {
    final trimmed = query.trim();
    if (trimmed == _searchQuery) return;

    _searchQuery = trimmed;
    _error = null;
    notifyListeners();

    if (trimmed.isEmpty) {
      _clearResults();
      return;
    }

    _runLocalSearch(trimmed);
    _scheduleGeocodeSearch(trimmed);
  }

  void _runLocalSearch(String query) {
    final exactStage = CorridorResolver.findExactStageMatch(query);
    if (exactStage != null) {
      final result = SearchResult.exactStage(
        query: query,
        stageName: exactStage.name,
        lat: exactStage.lat,
        lng: exactStage.lng,
        routeNumbers: exactStage.routeNumbers,
      );
      _updateResults([result], 'Local exact match');
    } else {
      final localStages = CorridorResolver.findStagesByName(query);
      if (localStages.isNotEmpty) {
        final results = localStages.map((s) => SearchResult.exactStage(
          query: query,
          stageName: s.name,
          lat: s.lat,
          lng: s.lng,
          routeNumbers: s.routeNumbers,
        )).toList();
        _updateResults(results, 'Local stage matches');
      }
    }
  }

  void _scheduleGeocodeSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: _debounceMs), () {
      _executeGeocodeSearch(query);
    });
  }

  Future<void> _executeGeocodeSearch(String query) async {
    final cacheKey = query.toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      _updateResults(_mergeLocal(cached, query), 'Cached');
      return;
    }

    _setLoading(true);
    _searchSource = 'Searching Mapbox...';
    notifyListeners();

    try {
      final geocodeResults =
          await _geocodingService.geocodeMultiple(query, limit: 5);
      final resolved = geocodeResults
          .map((g) => CorridorResolver.resolve(query, g))
          .toList();

      if (resolved.isEmpty) {
        // Genuinely no matches: the ROLE demands an explanatory message rather
        // than a silent blank list. Only surface it when local stages are also
        // missing for this query.
        if (_results.isNotEmpty && _results.first.source == SearchResultSource.exactStage) {
          _searchSource = 'Local stage matches only';
        } else {
          _error = 'No results found for "$query"';
          _searchSource = 'No results found';
        }
      } else {
        final merged = _mergeLocal(resolved, query);
        _addToCache(cacheKey, merged);
        _updateResults(merged, 'Mapbox Geocoding');

        _searchSource = 'Resolved via Mapbox';
        final matched = merged.where((r) => r.matchedCorridorName != null);
        if (matched.isNotEmpty) {
          _searchSource = 'Mapbox + ${matched.first.matchedCorridorName} corridor';
        }
        _error = null;
      }
    } on GeocodingError catch (e) {
      final offline = e.type == GeocodingErrorType.network ||
          e.type == GeocodingErrorType.timeout;
      // Keep the local stage results already on screen, and say why the list
      // is reduced rather than crashing or hanging.
      if (_results.isNotEmpty) {
        _error = offline
            ? 'Offline — showing local stage matches'
            : 'Geocoding limited — showing local stage matches';
        _searchSource = _error!;
      } else {
        _error = offline
            ? 'No network available'
            : 'Geocoding failed: ${e.message}';
        _searchSource = _error!;
      }
    } on Exception catch (e) {
      _error = 'Geocoding failed: $e';
      _searchSource = 'Error: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  /// Local stage matches come first (they carry routes), followed by geocoded
  /// places that aren't already represented by the same coordinate.
  List<SearchResult> _mergeLocal(List<SearchResult> geocoded, String query) {
    final local = _results
        .where((r) => r.source == SearchResultSource.exactStage)
        .toList();
    final seen = <String>{for (final r in local) r.nearestStageName};
    final merged = <SearchResult>[...local];
    for (final r in geocoded) {
      final key = _resultKey(r);
      if (seen.add(key)) merged.add(r);
    }
    return merged;
  }

  String _resultKey(SearchResult r) {
    final coords = '${r.lat.toStringAsFixed(5)},${r.lng.toStringAsFixed(5)}';
    if (r.source == SearchResultSource.exactStage) return r.nearestStageName;
    return '${r.resolvedLabel}|$coords';
  }

  void _updateResults(List<SearchResult> newResults, String source) {
    _results = newResults;
    _searchSource = source;
    _error = null;
    notifyListeners();
  }

  void _addToCache(String key, List<SearchResult> results) {
    if (_cache.length >= _cacheSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
    _cache[key] = results;
  }

  void _clearResults() {
    _results = [];
    _searchSource = '';
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clear() {
    _searchQuery = '';
    _clearResults();
    _cache.clear();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _geocodingService.dispose();
    super.dispose();
  }
}