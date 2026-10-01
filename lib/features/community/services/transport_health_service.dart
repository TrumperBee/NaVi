import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:navi_app/features/community/models/community_models.dart';
import 'package:navi_app/services/database/database_service.dart';

class TransportHealthService extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  TransportHealthMetric? _todayMetric;
  List<TransportHealthMetric> _history = [];
  bool _isLoading = false;

  TransportHealthMetric? get todayMetric => _todayMetric;
  List<TransportHealthMetric> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;

  Future<void> loadHealthData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _db.getCollectionData('transport_health');
      _history = data.map((entry) =>
          TransportHealthMetric.fromMap(entry['data'])).toList();
      _history.sort((a, b) => b.date.compareTo(a.date));
      _todayMetric = _history.isNotEmpty ? _history.first : null;
      if (_todayMetric == null || _todayMetric!.date.day != DateTime.now().day) {
        _todayMetric = await _computeTodayMetric();
        _history.insert(0, _todayMetric!);
        await _db.addDocument('transport_health', _todayMetric!.toMap());
      }
    } catch (_) {
      _todayMetric = await _computeTodayMetric();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<TransportHealthMetric> _computeTodayMetric() async {
    try {
      final reports = await _db.getCollectionData('wait_reports');
      const totalTrips = 42;
      final activeReports = reports.where((r) =>
          r['data'] is Map && (r['data']['status'] ?? 'active') == 'active').length;
      final resolvedReports = reports.where((r) =>
          r['data'] is Map && (r['data']['status'] ?? '') == 'resolved').length;

      double totalWait = 0;
      int waitCount = 0;
      for (final entry in reports) {
        final data = entry['data'] as Map<String, dynamic>?;
        if (data != null && data['wait_time'] != null) {
          totalWait += (data['wait_time'] as num).toDouble();
          waitCount++;
        }
      }
      final avgWait = waitCount > 0 ? totalWait / waitCount : 15.0;
      final reliability = max(0.0, min(1.0, 1.0 - (activeReports / max(1, totalTrips)) * 0.3));
      final congestion = max(0.0, min(1.0, activeReports / 20.0));

      return TransportHealthMetric(
        date: DateTime.now(),
        reliabilityScore: reliability,
        averageWaitTime: avgWait,
        congestionLevel: congestion,
        activeReports: activeReports,
        resolvedReports: resolvedReports,
        totalTrips: totalTrips,
        averageFare: 60.0,
        onTimePerformance: reliability * 0.9,
        worstRoutes: ['Route 44', 'Route 111'],
        bestRoutes: ['Route 58', 'Route 24'],
      );
    } catch (_) {
      return TransportHealthMetric(date: DateTime.now());
    }
  }

  double get weeklyReliabilityTrend {
    if (_history.length < 2) return 0;
    final recent = _history.take(7).toList();
    if (recent.length < 2) return 0;
    final first = recent.last.reliabilityScore;
    final last = recent.first.reliabilityScore;
    return first > 0 ? ((last - first) / first) * 100 : 0;
  }

  double get weeklyCongestionTrend {
    if (_history.length < 2) return 0;
    final recent = _history.take(7).toList();
    final first = recent.last.congestionLevel;
    final last = recent.first.congestionLevel;
    return first > 0 ? ((last - first) / first) * 100 : 0;
  }
}
