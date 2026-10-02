class SearchResult {
  final String query;
  final double lat;
  final double lng;
  final String resolvedLabel;

  /// Short area/road context line (e.g. "Westlands, Nairobi, Kenya") parsed
  /// from the Mapbox response; null for exact local stage matches.
  final String? secondaryLine;
  final String? matchedCorridorName;
  final String nearestStageName;
  final double nearestStageLat;
  final double nearestStageLng;
  final List<String> routeNumbers;
  final double distanceToStageMeters;
  final SearchResultSource source;

  const SearchResult({
    required this.query,
    required this.lat,
    required this.lng,
    required this.resolvedLabel,
    this.secondaryLine,
    this.matchedCorridorName,
    required this.nearestStageName,
    required this.nearestStageLat,
    required this.nearestStageLng,
    required this.routeNumbers,
    required this.distanceToStageMeters,
    required this.source,
  });

  factory SearchResult.exactStage({
    required String query,
    required String stageName,
    required double lat,
    required double lng,
    required List<String> routeNumbers,
  }) {
    return SearchResult(
      query: query,
      lat: lat,
      lng: lng,
      resolvedLabel: stageName,
      matchedCorridorName: null,
      nearestStageName: stageName,
      nearestStageLat: lat,
      nearestStageLng: lng,
      routeNumbers: routeNumbers,
      distanceToStageMeters: 0.0,
      source: SearchResultSource.exactStage,
    );
  }

  factory SearchResult.noTransitData({
    required String query,
    required double lat,
    required double lng,
    required String resolvedLabel,
    String? secondaryLine,
  }) {
    return SearchResult(
      query: query,
      lat: lat,
      lng: lng,
      resolvedLabel: resolvedLabel,
      secondaryLine: secondaryLine,
      matchedCorridorName: null,
      nearestStageName: 'No transit data nearby',
      nearestStageLat: lat,
      nearestStageLng: lng,
      routeNumbers: const [],
      distanceToStageMeters: double.infinity,
      source: SearchResultSource.mapboxGeocode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'query': query,
      'lat': lat,
      'lng': lng,
      'resolvedLabel': resolvedLabel,
      'secondaryLine': secondaryLine,
      'matchedCorridorName': matchedCorridorName,
      'nearestStageName': nearestStageName,
      'nearestStageLat': nearestStageLat,
      'nearestStageLng': nearestStageLng,
      'routeNumbers': routeNumbers,
      'distanceToStageMeters': distanceToStageMeters,
      'source': source.name,
    };
  }

  @override
  String toString() {
    return 'SearchResult(query: $query, resolvedLabel: $resolvedLabel, '
        'secondary: $secondaryLine, matchedCorridor: $matchedCorridorName, '
        'nearestStage: $nearestStageName, routes: $routeNumbers, '
        'distance: ${distanceToStageMeters.round()}m, source: $source)';
  }
}

enum SearchResultSource { exactStage, mapboxGeocode, localPlace }