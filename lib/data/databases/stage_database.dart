import 'dart:math' as math;
import 'package:navi_app/models/stage_record.dart';
import 'package:navi_app/data/seed_data.dart';
import 'package:navi_app/services/database/database_service.dart';
import 'package:navi_app/services/database/cache_manager.dart';
import 'package:navi_app/utils/geo_utils.dart';

class StageDatabase {
  static final StageDatabase _instance = StageDatabase._internal();
  factory StageDatabase() => _instance;
  StageDatabase._internal();

  DatabaseService? _db;
  final CacheManager _cache = CacheManager();

  List<StageRecord> _localIndex = [];
  bool _indexLoaded = false;

  Future<List<StageRecord>> getAllStages({bool forceRefresh = false}) async {
    if (forceRefresh || !_indexLoaded) {
      await _buildLocalIndex();
    }
    return _localIndex;
  }

  Future<StageRecord?> getStageById(String stageId) async {
    if (!_indexLoaded) await _buildLocalIndex();
    try {
      return _localIndex.firstWhere((s) => s.stageId == stageId);
    } catch (_) {
      return null;
    }
  }

  Future<List<StageRecord>> searchStages(String query) async {
    if (!_indexLoaded) await _buildLocalIndex();
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase().trim();
    final words = lowerQuery.split(RegExp(r'\s+'));

    final scored = <_ScoredStage>[];

    for (final stage in _localIndex) {
      double score = _computeSearchScore(stage, lowerQuery, words);
      if (score > 0) {
        scored.add(_ScoredStage(stage, score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.take(50).map((s) => s.stage).toList();
  }

  double _computeSearchScore(StageRecord stage, String query, List<String> words) {
    final name = stage.stageName.toLowerCase();
    final area = stage.area.toLowerCase();
    final road = stage.roadName.toLowerCase();
    final county = stage.county.toLowerCase();
    final routeText = stage.routesServed.join(' ').toLowerCase();

    final fields = [name, area, road, county, routeText];
    double totalScore = 0;

    for (final word in words) {
      double wordScore = 0;
      for (final field in fields) {
        if (field == word) {
          wordScore = math.max(wordScore, 1.0);
        } else if (field.startsWith(word)) {
          wordScore = math.max(wordScore, 0.9);
        } else if (field.contains(word)) {
          wordScore = math.max(wordScore, 0.7);
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
            wordScore = math.max(wordScore, fuzzy * 0.6);
          }
        }
      }
      totalScore += wordScore;
    }

    totalScore /= words.length;

    totalScore *= (1.0 + stage.popularityScore * 0.1);

    return totalScore;
  }

  Future<List<StageRecord>> findNearbyStages({
    required double latitude,
    required double longitude,
    double radiusMeters = 1000,
    int maxResults = 20,
  }) async {
    if (!_indexLoaded) await _buildLocalIndex();

    final scored = <_ScoredStage>[];

    for (final stage in _localIndex) {
      final distance = haversineDistance(
        latitude, longitude,
        stage.latitude, stage.longitude,
      );
      if (distance <= radiusMeters) {
        scored.add(_ScoredStage(stage, -distance));
      }
    }

    scored.sort((a, b) => a.score.compareTo(b.score));

    return scored.take(maxResults).map((s) => s.stage).toList();
  }

  Future<List<StageRecord>> getStagesByRoute(String routeNumber) async {
    if (!_indexLoaded) await _buildLocalIndex();
    return _localIndex
        .where((s) => s.routesServed.contains(routeNumber))
        .toList();
  }

  Future<List<StageRecord>> getStagesByArea(String area) async {
    if (!_indexLoaded) await _buildLocalIndex();
    final lowerArea = area.toLowerCase();
    return _localIndex
        .where((s) => s.area.toLowerCase().contains(lowerArea) ||
            s.area.toLowerCase() == lowerArea)
        .toList();
  }

  Future<List<StageRecord>> getStagesByRoad(String roadName) async {
    if (!_indexLoaded) await _buildLocalIndex();
    final lowerRoad = roadName.toLowerCase();
    return _localIndex
        .where((s) => s.roadName.toLowerCase().contains(lowerRoad) ||
            s.roadName.toLowerCase() == lowerRoad)
        .toList();
  }

  Future<List<StageRecord>> getPopularStages({int limit = 20}) async {
    if (!_indexLoaded) await _buildLocalIndex();
    final sorted = List<StageRecord>.from(_localIndex)
      ..sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
    return sorted.take(limit).toList();
  }

  Future<void> updatePopularity(String stageId, {double increment = 0.1}) async {
    try {
      await (_db ??= DatabaseService()).getStageById(stageId);
    } catch (_) {}
  }

  Future<int> getStageCount() async {
    if (!_indexLoaded) await _buildLocalIndex();
    return _localIndex.length;
  }

  Future<void> _buildLocalIndex() async {
    final cached = _cache.getCachedStages();

    if (cached != null && cached.isNotEmpty) {
      _localIndex = cached.map((s) => StageRecord(
        stageId: s.id,
        stageName: s.name,
        latitude: s.lat,
        longitude: s.lng,
        roadName: s.corridor,
        area: s.area ?? '',
        county: 'Nairobi',
        routesServed: s.routes,
        popularityScore: (s.totalReports ?? 0).toDouble(),
      )).toList();
      _indexLoaded = true;
      return;
    }

    final seedStages = SeedData.getStages();
    _localIndex = seedStages.map((s) => StageRecord(
      stageId: s.id,
      stageName: s.name,
      latitude: s.lat,
      longitude: s.lng,
      roadName: s.corridor,
      area: s.area ?? '',
      county: 'Nairobi',
      routesServed: s.routes,
      popularityScore: (s.totalReports ?? 0).toDouble(),
    )).toList();
    _indexLoaded = true;
  }


}

class _ScoredStage {
  final StageRecord stage;
  final double score;
  _ScoredStage(this.stage, this.score);
}
