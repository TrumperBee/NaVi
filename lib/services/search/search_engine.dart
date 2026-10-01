import 'package:flutter/foundation.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/data/databases/route_database.dart';
import 'package:navi_app/models/stage_record.dart';
import 'package:navi_app/models/route_record.dart';

enum SearchCategory {
  stage,
  route,
  landmark,
  building,
  estate,
  university,
  business,
  hospital,
  policeStation,
  all,
}

class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final SearchCategory category;
  final double score;
  final double? latitude;
  final double? longitude;
  final String? stageId;
  final String? routeNumber;

  SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.score,
    this.latitude,
    this.longitude,
    this.stageId,
    this.routeNumber,
  });
}

class SearchEngine extends ChangeNotifier {
  static final SearchEngine _instance = SearchEngine._init();
  factory SearchEngine() => _instance;

  final StageDatabase _stageDb = StageDatabase();
  final RouteDatabase _routeDb = RouteDatabase();

  final List<String> _nairobiLandmarks = [
    'Kenyatta International Convention Centre', 'KICC', 'Uhuru Park',
    'Nairobi National Park', 'Nairobi National Museum', 'Bomas of Kenya',
    'Nairobi Arboretum', 'Karura Forest', 'Nairobi Safari Walk',
    'Nairobi Railway Museum', 'Parliament Buildings', 'State House',
    'The Village Market', 'Two Rivers Mall', 'Garden City Mall',
    'Sarit Centre', 'Westgate Shopping Mall', 'Thika Road Mall',
    'The Hub Karen', 'Galleria Shopping Mall', 'Junction Mall',
    'TRM Drive', 'Yaya Centre', 'Prestige Plaza',
    'Nairobi Hospital', 'Aga Khan Hospital', 'Kenyatta National Hospital',
    'Mater Hospital', 'MP Shah Hospital', 'Nairobi Women\'s Hospital',
    'JKIA', 'Jomo Kenyatta International Airport', 'Wilson Airport',
    'Nairobi Railway Station', 'Mombasa Road', 'Thika Road',
    'Ngong Road', 'Lang\'ata Road', 'Waiyaki Way',
    'University of Nairobi', 'Kenyatta University', 'Strathmore University',
    'Daystar University', 'USIU', 'JKUAT',
    'KCA University', 'Mount Kenya University', 'Catholic University',
  ];

  final List<String> _nairobiEstates = [
    'South B', 'South C', 'Eastleigh', 'Buruburu', 'Umoja',
    'Kayole', 'Dandora', 'Kariobangi', 'Mathare', 'Korogocho',
    'Kawangware', 'Kangemi', 'Dagoretti', 'Riruta', 'Karen',
    'Lang\'ata', 'Kitisuru', 'Lavington', 'Kilimani', 'Kileleshwa',
    'Westlands', 'Parklands', 'Ngara', 'Pangani', 'Huruma',
    'Mbotela', 'Bahati', 'Kariokor', 'Shauri Moyo', 'Makadara',
    'Donholm', 'Nyayo Estate', 'Embakasi', 'Pipeline', 'Fedha',
    'Roysambu', 'Zimmerman', 'Githurai', 'Kahawa', 'Kasarani',
    'Highridge', 'Upper Hill', 'Riverside', 'Spring Valley', 'Kileleshwa',
    'Madaraka', 'Nairobi West', 'Nairobi South',
  ];

  final List<String> _nairobiUniversities = [
    'University of Nairobi', 'Kenyatta University', 'Strathmore University',
    'Daystar University', 'USIU', 'JKUAT Nairobi',
    'KCA University', 'Mount Kenya University', 'Catholic University',
    'MultiMedia University', 'Technical University of Kenya',
    'Co-operative University', 'Pioneer University',
  ];

  final List<String> _nairobiHospitals = [
    'Kenyatta National Hospital', 'Aga Khan Hospital', 'Nairobi Hospital',
    'Mater Hospital', 'MP Shah Hospital', 'Nairobi Women\'s Hospital',
    'Coptic Hospital', 'Gertrude\'s Garden Hospital',
    'Metropolitan Hospital', 'Kikuyu Mission Hospital',
  ];

  final Map<String, double> _locationCoordinates = {};

  SearchEngine._init() {
    _initKnownLocations();
  }

  void _initKnownLocations() {
    final coords = <String, List<double>>{
      'KICC': [-1.2887, 36.8235],
      'Uhuru Park': [-1.2875, 36.8142],
      'Nairobi National Museum': [-1.3178, 36.8112],
      'JKIA': [-1.3190, 36.9278],
      'University of Nairobi': [-1.2797, 36.8136],
      'Kenyatta University': [-1.1786, 36.9324],
      'Strathmore University': [-1.3147, 36.8139],
      'USIU': [-1.2144, 36.8889],
      'JKUAT Nairobi': [-1.2747, 36.8364],
      'Kenyatta National Hospital': [-1.2995, 36.8148],
      'Aga Khan Hospital': [-1.2608, 36.8097],
      'Nairobi Hospital': [-1.2936, 36.8178],
      'Mater Hospital': [-1.2953, 36.8194],
      'Two Rivers Mall': [-1.1992, 36.8778],
      'Sarit Centre': [-1.2581, 36.8006],
      'Westgate Mall': [-1.2600, 36.8025],
      'Garden City Mall': [-1.1967, 36.8831],
      'The Hub Karen': [-1.3400, 36.7169],
      'Village Market': [-1.2222, 36.8789],
      'Thika Road Mall': [-1.1911, 36.8789],
      'Galleria Mall': [-1.3422, 36.7442],
      'Nairobi Railway Museum': [-1.2911, 36.8239],
      'Karura Forest': [-1.2375, 36.8361],
      'Bomas of Kenya': [-1.3778, 36.7467],
      'Nairobi National Park': [-1.3769, 36.8589],
      'Nairobi Arboretum': [-1.2750, 36.8097],
    };
    for (final entry in coords.entries) {
      _locationCoordinates[entry.key.toLowerCase()] =
          entry.value[0] + entry.value[1] / 1000;
    }
  }

  Future<List<SearchResult>> search(String query, {
    SearchCategory category = SearchCategory.all,
    double? userLat,
    double? userLng,
    int maxResults = 30,
  }) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase().trim();
    final words = lowerQuery.split(RegExp(r'\s+'));

    final results = <SearchResult>[];

    if (category == SearchCategory.all || category == SearchCategory.stage) {
      final stages = await _stageDb.searchStages(query);
      for (final stage in stages) {
        results.add(SearchResult(
          id: stage.stageId,
          title: stage.stageName,
          subtitle: '${stage.area} - ${stage.roadName}',
          category: SearchCategory.stage,
          score: _computeStageScore(stage, query),
          latitude: stage.latitude,
          longitude: stage.longitude,
          stageId: stage.stageId,
        ));
      }
    }

    if (category == SearchCategory.all || category == SearchCategory.route) {
      final routes = await _routeDb.searchRoutes(query);
      for (final route in routes) {
        results.add(SearchResult(
          id: route.routeId,
          title: 'Route ${route.routeNumber}: ${route.routeName}',
          subtitle: '${route.startStage} → ${route.endStage} via ${route.corridor}',
          category: SearchCategory.route,
          score: _computeRouteScore(route, query),
          routeNumber: route.routeNumber,
        ));
      }
    }

    results.addAll(_searchKnownLocations(lowerQuery, words, userLat, userLng));
    results.addAll(_searchEstates(lowerQuery, words));
    results.addAll(_searchUniversities(lowerQuery, words));
    results.addAll(_searchHospitals(lowerQuery, words));

    results.sort((a, b) => b.score.compareTo(a.score));

    return results.take(maxResults).toList();
  }

  List<SearchResult> _searchKnownLocations(
    String lowerQuery, List<String> words, double? userLat, double? userLng,
  ) {
    final results = <SearchResult>[];
    for (final landmark in _nairobiLandmarks) {
      final lower = landmark.toLowerCase();
      double score = _matchScore(lower, lowerQuery, words);
      if (score > 0) {
        results.add(SearchResult(
          id: 'landmark_$landmark',
          title: landmark,
          subtitle: 'Landmark',
          category: SearchCategory.landmark,
          score: score,
        ));
      }
    }
    return results;
  }

  List<SearchResult> _searchEstates(String lowerQuery, List<String> words) {
    final results = <SearchResult>[];
    for (final estate in _nairobiEstates) {
      final lower = estate.toLowerCase();
      double score = _matchScore(lower, lowerQuery, words);
      if (score > 0) {
        results.add(SearchResult(
          id: 'estate_$estate',
          title: estate,
          subtitle: 'Estate/Neighborhood',
          category: SearchCategory.estate,
          score: score,
        ));
      }
    }
    return results;
  }

  List<SearchResult> _searchUniversities(String lowerQuery, List<String> words) {
    final results = <SearchResult>[];
    for (final uni in _nairobiUniversities) {
      final lower = uni.toLowerCase();
      double score = _matchScore(lower, lowerQuery, words);
      if (score > 0) {
        results.add(SearchResult(
          id: 'uni_$uni',
          title: uni,
          subtitle: 'University',
          category: SearchCategory.university,
          score: score,
        ));
      }
    }
    return results;
  }

  List<SearchResult> _searchHospitals(String lowerQuery, List<String> words) {
    final results = <SearchResult>[];
    for (final hospital in _nairobiHospitals) {
      final lower = hospital.toLowerCase();
      double score = _matchScore(lower, lowerQuery, words);
      if (score > 0) {
        results.add(SearchResult(
          id: 'hospital_$hospital',
          title: hospital,
          subtitle: 'Hospital',
          category: SearchCategory.hospital,
          score: score,
        ));
      }
    }
    return results;
  }

  double _matchScore(String field, String query, List<String> words) {
    double score = 0;
    for (final word in words) {
      if (field == word) {
        score += 1.0;
      } else if (field.startsWith(word)) {
        score += 0.9;
      } else if (field.contains(word)) {
        score += 0.7;
      } else {
        int matches = 0;
        int fieldIdx = 0;
        for (int q = 0; q < word.length; q++) {
          while (fieldIdx < field.length && field[fieldIdx] != word[q]) {
            fieldIdx++;
          }
          if (fieldIdx < field.length) {
            matches++;
            fieldIdx++;
          }
        }
        final fuzzy = matches / word.length;
        if (fuzzy > 0.6) {
          score += fuzzy * 0.6;
        }
      }
    }
    return score / words.length;
  }

  double _computeStageScore(StageRecord stage, String query) {
    final lowerQuery = query.toLowerCase();
    double score = _matchScore(stage.stageName.toLowerCase(), lowerQuery, lowerQuery.split(' '));
    score += (1.0 + stage.popularityScore * 0.1);
    return score;
  }

  double _computeRouteScore(RouteRecord route, String query) {
    final lowerQuery = query.toLowerCase();
    double score = 0;
    if (route.routeNumber.toLowerCase().contains(lowerQuery)) score += 1.0;
    if (route.routeName.toLowerCase().contains(lowerQuery)) score += 0.9;
    if (route.corridor.toLowerCase().contains(lowerQuery)) score += 0.7;
    if (route.sacco.toLowerCase().contains(lowerQuery)) score += 0.5;
    return score;
  }

  List<String> getSearchSuggestions(String query) {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return [];
    final suggestions = <String>{};
    for (final landmark in _nairobiLandmarks) {
      if (landmark.toLowerCase().startsWith(lowerQuery) ||
          landmark.toLowerCase().contains(lowerQuery)) {
        suggestions.add(landmark);
      }
    }
    for (final estate in _nairobiEstates) {
      if (estate.toLowerCase().startsWith(lowerQuery)) {
        suggestions.add(estate);
      }
    }
    return suggestions.take(5).toList();
  }
}
