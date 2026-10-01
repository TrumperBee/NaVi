import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/services/database/database_service.dart';
import 'package:navi_app/services/database/cache_manager.dart';
import 'package:navi_app/data/seed_data.dart';

class RouteRepository {
  final DatabaseService _db = DatabaseService();
  final CacheManager _cache = CacheManager();

  Stream<List<RouteModel>> watchRoutes() {
    return _db.getRoutes();
  }

  Future<List<RouteModel>> getRoutes() async {
    final cached = _cache.getCachedRoutes();
    if (cached != null) {
      return cached;
    }
    try {
      final routes = await _db.getRoutes().first;
      await _cache.cacheRoutes(routes);
      return routes;
    } catch (e) {
      if (cached != null) return cached;
      return SeedData.getRoutes();
    }
  }

  Future<List<RouteModel>> getRoutesByStage(String stageId) async {
    try {
      return await _db.getRoutesByStage(stageId);
    } catch (e) {
      return SeedData.getRoutesForStage(stageId);
    }
  }

  Future<RouteModel?> getRouteById(String id) async {
    try {
      return await _db.getRouteById(id);
    } catch (e) {
      try {
        return SeedData.getRoutes().firstWhere((r) => r.id == id);
      } catch (_) {
        return null;
      }
    }
  }
}
