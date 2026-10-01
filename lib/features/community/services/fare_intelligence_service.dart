import 'package:flutter/foundation.dart';
import 'package:navi_app/features/community/models/community_models.dart';
import 'package:navi_app/services/database/database_service.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/models/stage_record.dart';

class FareIntelligenceService extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final StageDatabase _stageDb = StageDatabase();

  List<FareIntelligence> _intelligenceData = [];
  bool _isLoading = false;

  List<FareIntelligence> get intelligenceData => List.unmodifiable(_intelligenceData);
  bool get isLoading => _isLoading;

  Future<void> loadIntelligence() async {
    _isLoading = true;
    notifyListeners();
    try {
      final stages = await _stageDb.getPopularStages(limit: 20);
      _intelligenceData = [];
      for (final stage in stages) {
        final intelligence = await _calculateForStage(stage);
        _intelligenceData.add(intelligence);
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<FareIntelligence> _calculateForStage(StageRecord stage) async {
    try {
      final fareStats = await _db.getAverageFare(stage.stageId);
      final currentAvg = fareStats['mean'] ?? 50.0;
      final minFare = fareStats['min'] ?? 50.0;
      final maxFare = fareStats['max'] ?? 50.0;
      final count = (fareStats['count'] ?? 0).toInt();

      final now = DateTime.now();
      final hourlyAverages = <int, double>{};
      for (int h = 0; h < 24; h++) {
        hourlyAverages[h] = currentAvg + (h >= 7 && h <= 9 ? 10 : h >= 17 && h <= 19 ? 8 : 0);
      }

      final dailyAverages = <int, double>{};
      for (int d = 1; d <= 7; d++) {
        dailyAverages[d] = currentAvg + (d == 1 || d == 7 ? 5 : 0);
      }

      return FareIntelligence(
        stageId: stage.stageId,
        stageName: stage.stageName,
        currentAverage: currentAvg,
        previousAverage: currentAvg * 0.95,
        minFare: minFare,
        maxFare: maxFare,
        reportCount: count,
        periodStart: now.subtract(const Duration(days: 30)),
        periodEnd: now,
        hourlyAverages: hourlyAverages,
        dailyAverages: dailyAverages,
        trend: 5.0,
      );
    } catch (_) {
      return FareIntelligence(
        stageId: stage.stageId,
        stageName: stage.stageName,
        currentAverage: 50,
        previousAverage: 50,
        minFare: 50,
        maxFare: 50,
        reportCount: 0,
        periodStart: DateTime.now().subtract(const Duration(days: 30)),
        periodEnd: DateTime.now(),
        hourlyAverages: {},
        dailyAverages: {},
      );
    }
  }

  FareIntelligence? getIntelligenceForStage(String stageId) {
    try {
      return _intelligenceData.firstWhere((i) => i.stageId == stageId);
    } catch (_) {
      return null;
    }
  }

  List<FareIntelligence> getStagesWithRisingFares() {
    final sorted = List<FareIntelligence>.from(_intelligenceData);
    sorted.sort((a, b) => b.change.compareTo(a.change));
    return sorted.take(5).toList();
  }

  List<FareIntelligence> getBestValueStages() {
    final sorted = List<FareIntelligence>.from(_intelligenceData);
    sorted.sort((a, b) => a.currentAverage.compareTo(b.currentAverage));
    return sorted.take(5).toList();
  }

  Map<int, double> getSystemWideHourlyAverage() {
    if (_intelligenceData.isEmpty) return {};
    final hourlyTotals = <int, double>{};
    final hourlyCounts = <int, int>{};
    for (final data in _intelligenceData) {
      for (final entry in data.hourlyAverages.entries) {
        hourlyTotals[entry.key] = (hourlyTotals[entry.key] ?? 0) + entry.value;
        hourlyCounts[entry.key] = (hourlyCounts[entry.key] ?? 0) + 1;
      }
    }
    return hourlyTotals.map((k, v) => MapEntry(k, v / hourlyCounts[k]!));
  }
}
