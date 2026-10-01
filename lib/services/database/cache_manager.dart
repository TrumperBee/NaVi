import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/models/wait_report_model.dart';

class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  static const String _stagesCache = 'stages_cache';
  static const String _routesCache = 'routes_cache';
  static const String _placesCache = 'places_cache';
  static const String _reportsCache = 'reports_cache';

  Box? _stagesBox;
  Box? _routesBox;
  Box? _placesBox;
  Box? _reportsBox;

  Future<void> init() async {
    _stagesBox = await Hive.openBox(_stagesCache);
    _routesBox = await Hive.openBox(_routesCache);
    _placesBox = await Hive.openBox(_placesCache);
    _reportsBox = await Hive.openBox(_reportsCache);
  }

  // ==================== STAGES ====================

  Future<void> cacheStages(List<StageModel> stages) async {
    final data = stages.map((s) => s.toMap()).toList();
    await _stagesBox?.put('stages', jsonEncode(data));
    await _stagesBox?.put('timestamp', DateTime.now().toIso8601String());
  }

  List<StageModel>? getCachedStages() {
    final raw = _stagesBox?.get('stages');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw as String) as List;
      return data.map((item) {
        return StageModel.fromMap(item as Map<String, dynamic>, item['id'] ?? '');
      }).toList();
    } catch (e) {
      print('Error decoding cached stages: $e');
      return null;
    }
  }

  bool get isStageCacheFresh {
    final timestamp = _stagesBox?.get('timestamp');
    if (timestamp == null) return false;
    final cachedTime = DateTime.parse(timestamp as String);
    return DateTime.now().difference(cachedTime).inHours < 24;
  }

  // ==================== ROUTES ====================

  Future<void> cacheRoutes(List<RouteModel> routes) async {
    final data = routes.map((r) => r.toMap()).toList();
    await _routesBox?.put('routes', jsonEncode(data));
  }

  List<RouteModel>? getCachedRoutes() {
    final raw = _routesBox?.get('routes');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw as String) as List;
      return data.map((item) {
        return RouteModel.fromMap(item as Map<String, dynamic>, item['id'] ?? '');
      }).toList();
    } catch (e) {
      print('Error decoding cached routes: $e');
      return null;
    }
  }

  // ==================== PLACES ====================

  Future<void> cachePlaces(List<PlaceModel> places) async {
    final data = places.map((p) => p.toMap()).toList();
    await _placesBox?.put('places', jsonEncode(data));
  }

  List<PlaceModel>? getCachedPlaces() {
    final raw = _placesBox?.get('places');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw as String) as List;
      return data.map((item) {
        return PlaceModel.fromMap(item as Map<String, dynamic>, item['id'] ?? '');
      }).toList();
    } catch (e) {
      print('Error decoding cached places: $e');
      return null;
    }
  }

  // ==================== REPORTS ====================

  Future<void> cacheReports(List<WaitReportModel> reports) async {
    final data = reports.map((r) => r.toMap()).toList();
    await _reportsBox?.put('reports', jsonEncode(data));
    await _reportsBox?.put('timestamp', DateTime.now().toIso8601String());
  }

  List<WaitReportModel>? getCachedReports() {
    final raw = _reportsBox?.get('reports');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw as String) as List;
      return data.map((item) {
        return WaitReportModel.fromMap(item as Map<String, dynamic>, item['id'] ?? '');
      }).toList();
    } catch (e) {
      print('Error decoding cached reports: $e');
      return null;
    }
  }

  bool get isReportsCacheFresh {
    final timestamp = _reportsBox?.get('timestamp');
    if (timestamp == null) return false;
    final cachedTime = DateTime.parse(timestamp as String);
    return DateTime.now().difference(cachedTime).inMinutes < 30;
  }

  // ==================== ANALYTICS ====================

  Future<void> cacheAnalytics(List<dynamic> events) async {
    final box = await Hive.openBox('analytics_cache');
    final existing = box.get('events', defaultValue: <dynamic>[]);
    final all = [...events.map((e) => e is Map ? e : (e as dynamic).toMap()), ...existing];
    final trimmed = all.length > 500 ? all.sublist(0, 500) : all;
    await box.put('events', trimmed);
  }

  List<Map<String, dynamic>> getCachedAnalytics() {
    final box = Hive.box('analytics_cache');
    final raw = box.get('events', defaultValue: <dynamic>[]);
    return (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ==================== CLEAR ====================

  Future<void> clearAll() async {
    await _stagesBox?.clear();
    await _routesBox?.clear();
    await _placesBox?.clear();
    await _reportsBox?.clear();
  }
}
