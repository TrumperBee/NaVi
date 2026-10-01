import 'package:navi_app/models/wait_report_model.dart';
import 'package:navi_app/services/database/database_service.dart';
import 'package:navi_app/services/database/cache_manager.dart';

class ReportRepository {
  final DatabaseService _db = DatabaseService();
  final CacheManager _cache = CacheManager();

  Future<String?> submitReport(WaitReportModel report) async {
    return await _db.submitReport(report);
  }

  Future<List<WaitReportModel>> getRecentReports({
    required String stageId,
    required String routeId,
    int limit = 50,
  }) async {
    try {
      return await _db.getRecentReports(
        stageId: stageId,
        routeId: routeId,
        limit: limit,
      );
    } catch (e) {
      final cached = _cache.getCachedReports();
      if (cached != null) {
        return cached.where((r) =>
            r.stageId == stageId && r.routeId == routeId
        ).take(limit).toList();
      }
      return [];
    }
  }

  Future<Map<String, dynamic>> getReportStatistics({
    required String stageId,
    required String routeId,
    int days = 7,
  }) async {
    return await _db.getReportStatistics(
      stageId: stageId,
      routeId: routeId,
      days: days,
    );
  }

  Future<List<WaitReportModel>> getAllReports({int limit = 1000}) async {
    final cached = _cache.getCachedReports();
    if (cached != null && _cache.isReportsCacheFresh) {
      return cached;
    }
    try {
      final reports = await _db.getAllReports(limit: limit);
      await _cache.cacheReports(reports);
      return reports;
    } catch (e) {
      if (cached != null) return cached;
      return [];
    }
  }
}
