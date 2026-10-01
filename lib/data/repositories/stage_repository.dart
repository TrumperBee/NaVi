import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/services/database/database_service.dart';
import 'package:navi_app/services/database/cache_manager.dart';
import 'package:navi_app/data/seed_data.dart';

class StageRepository {
  final DatabaseService _db = DatabaseService();
  final CacheManager _cache = CacheManager();

  Stream<List<StageModel>> watchStages() {
    return _db.getStages();
  }

  Future<List<StageModel>> getStages() async {
    final cached = _cache.getCachedStages();
    if (cached != null && _cache.isStageCacheFresh) {
      return cached;
    }
    try {
      final stages = await _db.getStagesWithRetry();
      await _cache.cacheStages(stages);
      return stages;
    } catch (e) {
      if (cached != null) return cached;
      return SeedData.getStages();
    }
  }

  Future<List<StageModel>> getStagesByCorridor(String corridor) async {
    try {
      return await _db.getStagesByCorridor(corridor);
    } catch (e) {
      return SeedData.getStagesByCorridor(corridor);
    }
  }

  Future<StageModel?> getStageById(String id) async {
    try {
      return await _db.getStageById(id);
    } catch (e) {
      final stages = SeedData.getStages();
      try {
        return stages.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    }
  }
}
