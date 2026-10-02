import 'package:flutter/foundation.dart';
import 'package:navi_app/features/community/models/community_models.dart';
import 'package:navi_app/models/fare_estimate_record.dart';
import 'package:navi_app/services/database/database_service.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/models/stage_record.dart';
import 'package:navi_app/services/fare_estimate_registry.dart';

class FareIntelligenceService extends ChangeNotifier {
  // Lazy: construction of the service must not touch Firestore (the §1.6
  // report/verify methods work purely against the in-memory registry and are
  // unit-tested without a Firebase app).
  late final DatabaseService _db = DatabaseService();
  late final StageDatabase _stageDb = StageDatabase();

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

  // ==================== §1.6 fare_estimates write path ====================
  //
  // The legacy `DatabaseService.submitFareReport(stageId, fare)` writes
  // stage-level analytics (the averages above). Real-world fare *estimates*
  // live in `FareEstimateRegistry` keyed on the (route, from, to) tuple the
  // spec requires, so this service owns that write path: submissions land as
  // UNVERIFIED, and only a reviewer's [verifyRouteFareEstimate] promotes a
  // row to the verified confidence that the §1.6 resolution order honours.

  /// Records a contributor-reported fare for one leg. Stored unverified: it
  /// exists for review but does not affect displayed fares until it passes
  /// the reviewer gate in [verifyRouteFareEstimate].
  void submitRouteFareEstimate({
    required String routeId,
    required String fromStageId,
    required String toStageId,
    required int estimatedOffpeak,
    required int estimatedPeak,
    String? reportedBy,
    DateTime? observedAt,
  }) {
    FareEstimateRegistry.upsert(FareEstimateRecord(
      routeId: routeId,
      fromStageId: fromStageId,
      toStageId: toStageId,
      estimatedOffpeak: estimatedOffpeak,
      estimatedPeak: estimatedPeak,
      confidence: FareConfidence.unverified,
      lastVerified: observedAt ?? DateTime.now(),
      reportedBy: reportedBy,
    ));
  }

  /// Reviewer gate — spec §6: "Verified is system-set during review",
  /// never contributor-editable. Promotes the stored row for this tuple so
  /// the resolution order starts honouring it. No-op if nothing is stored.
  void verifyRouteFareEstimate({
    required String routeId,
    required String fromStageId,
    required String toStageId,
    DateTime? verifiedAt,
  }) {
    FareEstimateRegistry.markVerified(
      routeId: routeId,
      fromStageId: fromStageId,
      toStageId: toStageId,
      verifiedAt: verifiedAt,
    );
  }
}
