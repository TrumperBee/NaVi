import 'package:navi_app/models/route_record.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/data/seed_data.dart';
import 'package:navi_app/services/database/cache_manager.dart';

class RouteDatabase {
  static final RouteDatabase _instance = RouteDatabase._internal();
  factory RouteDatabase() => _instance;
  RouteDatabase._internal();

  final CacheManager _cache = CacheManager();

  List<RouteRecord> _localIndex = [];
  bool _indexLoaded = false;

  Future<List<RouteRecord>> getAllRoutes({bool forceRefresh = false}) async {
    if (forceRefresh || !_indexLoaded) {
      await _buildLocalIndex();
    }
    return _localIndex;
  }

  Future<RouteRecord?> getRouteById(String routeId) async {
    if (!_indexLoaded) await _buildLocalIndex();
    try {
      return _localIndex.firstWhere((r) => r.routeId == routeId);
    } catch (_) {
      return null;
    }
  }

  Future<List<RouteRecord>> getRoutesByStage(String stageId, StageDatabase stageDb) async {
    if (!_indexLoaded) await _buildLocalIndex();
    final stage = await stageDb.getStageById(stageId);
    if (stage == null) return [];

    return _localIndex.where((route) {
      return route.orderedStages.contains(stage.stageName) ||
          route.startStage == stage.stageName ||
          route.endStage == stage.stageName ||
          stage.routesServed.contains(route.routeNumber);
    }).toList();
  }

  Future<List<RouteRecord>> getRoutesByCorridor(String corridor) async {
    if (!_indexLoaded) await _buildLocalIndex();
    final lowerCorridor = corridor.toLowerCase();
    return _localIndex.where((r) =>
        r.corridor.toLowerCase().contains(lowerCorridor)
    ).toList();
  }

  Future<List<RouteRecord>> searchRoutes(String query) async {
    if (!_indexLoaded) await _buildLocalIndex();
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase().trim();
    return _localIndex.where((r) {
      return r.routeNumber.toLowerCase().contains(lowerQuery) ||
          r.routeName.toLowerCase().contains(lowerQuery) ||
          r.corridor.toLowerCase().contains(lowerQuery) ||
          r.sacco.toLowerCase().contains(lowerQuery) ||
          r.orderedStages.any((s) => s.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  Future<List<RouteRecord>> findRoutesBetweenStages(
    String startStageId,
    String endStageId,
    StageDatabase stageDb,
  ) async {
    if (!_indexLoaded) await _buildLocalIndex();

    final startStage = await stageDb.getStageById(startStageId);
    final endStage = await stageDb.getStageById(endStageId);

    if (startStage == null || endStage == null) return [];

    return _localIndex.where((route) {
      final startIdx = route.orderedStages.indexOf(startStage.stageName);
      final endIdx = route.orderedStages.indexOf(endStage.stageName);
      return startIdx >= 0 && endIdx > startIdx;
    }).toList();
  }

  Future<List<RouteRecord>> getActiveRoutes() async {
    if (!_indexLoaded) await _buildLocalIndex();
    return _localIndex.where((r) => r.isActive).toList();
  }

  Future<List<RouteRecord>> getRoutesBySacco(String sacco) async {
    if (!_indexLoaded) await _buildLocalIndex();
    final lowerSacco = sacco.toLowerCase();
    return _localIndex.where((r) =>
        r.sacco.toLowerCase().contains(lowerSacco)
    ).toList();
  }

  Future<List<RouteRecord>> getRoutesByFareRange({
    double minFare = 0,
    double maxFare = double.infinity,
  }) async {
    if (!_indexLoaded) await _buildLocalIndex();
    return _localIndex.where((r) =>
        r.estimatedFare >= minFare && r.estimatedFare <= maxFare
    ).toList();
  }

  Future<List<RouteRecord>> getPopularRoutes({int limit = 20}) async {
    return [];
  }

  Future<int> getRouteCount() async {
    if (!_indexLoaded) await _buildLocalIndex();
    return _localIndex.length;
  }

  Future<void> _buildLocalIndex() async {
    final cached = _cache.getCachedRoutes();

    if (cached != null && cached.isNotEmpty) {
      _localIndex = cached.map((r) => RouteRecord(
        routeId: r.id,
        routeNumber: r.number,
        routeName: r.name,
        startStage: r.majorStops.isNotEmpty ? r.majorStops.first : '',
        endStage: r.majorStops.isNotEmpty ? r.majorStops.last : '',
        orderedStages: r.majorStops,
        estimatedFare: r.baseFare,
        peakFare: r.baseFare * 1.2,
        offpeakFare: r.baseFare * 0.9,
        averageDuration: r.estimatedTime ?? 0,
        activeStatus: true,
        corridor: r.corridor,
        sacco: r.sacco,
        description: r.description,
        distance: r.distance,
        trafficLevel: r.trafficLevel ?? 'medium',
      )).toList();
      _indexLoaded = true;
      return;
    }

    final seedRoutes = SeedData.getRoutes();
    _localIndex = seedRoutes.map((r) => RouteRecord(
      routeId: r.id,
      routeNumber: r.number,
      routeName: r.name,
      startStage: r.majorStops.isNotEmpty ? r.majorStops.first : '',
      endStage: r.majorStops.isNotEmpty ? r.majorStops.last : '',
      orderedStages: r.majorStops,
      estimatedFare: r.baseFare,
      peakFare: r.baseFare * 1.2,
      offpeakFare: r.baseFare * 0.9,
      averageDuration: r.estimatedTime ?? 0,
      activeStatus: true,
      corridor: r.corridor,
      sacco: r.sacco,
      description: r.description,
      distance: r.distance,
      trafficLevel: r.trafficLevel ?? 'medium',
    )).toList();
    _indexLoaded = true;
  }
}
