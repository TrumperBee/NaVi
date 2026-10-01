import 'package:navi_app/services/intelligence/prediction_engine.dart';
import 'package:navi_app/services/reporting/report_service.dart';
import 'package:navi_app/data/databases/route_database.dart';
import 'package:navi_app/data/databases/stage_database.dart';

class RouteRecommendation {
  final String routeId;
  final String routeNumber;
  final String routeName;
  final int estimatedMinutes;
  final double estimatedFare;
  final String congestionLevel;
  final double recommendationScore;
  final String reason;
  final double confidence;

  RouteRecommendation({
    required this.routeId,
    required this.routeNumber,
    required this.routeName,
    required this.estimatedMinutes,
    required this.estimatedFare,
    required this.congestionLevel,
    required this.recommendationScore,
    required this.reason,
    this.confidence = 0.5,
  });
}

class RecommendationContext {
  final String fromStageId;
  final String toStageId;
  final DateTime currentTime;
  final bool preferCheapest;
  final bool preferFastest;
  final bool preferLessCongested;
  final double? userLatitude;
  final double? userLongitude;

  RecommendationContext({
    required this.fromStageId,
    required this.toStageId,
    DateTime? currentTime,
    this.preferCheapest = false,
    this.preferFastest = false,
    this.preferLessCongested = false,
    this.userLatitude,
    this.userLongitude,
  }) : currentTime = currentTime ?? DateTime.now();

  bool get isPeakHour {
    final h = currentTime.hour;
    return (h >= 6 && h <= 9) || (h >= 16 && h <= 19);
  }
}

class RecommendationEngine {
  static final RecommendationEngine _instance = RecommendationEngine._internal();
  factory RecommendationEngine() => _instance;
  RecommendationEngine._internal();

  final RouteDatabase _routeDb = RouteDatabase();
  final StageDatabase _stageDb = StageDatabase();
  final PredictionEngine _predictor = PredictionEngine();
  final ReportService _reportService = ReportService();
  Future<List<RouteRecommendation>> getRecommendations(RecommendationContext ctx) async {
    final routes = await _routeDb.findRoutesBetweenStages(
      ctx.fromStageId, ctx.toStageId, _stageDb,
    );

    if (routes.isEmpty) return [];

    final inputs = routes.map((r) => PredictionInput.now(
      stageId: ctx.fromStageId,
      stageName: r.startStage,
      routeId: r.routeId,
      routeNumber: r.routeNumber,
      corridor: r.corridor,
    )).toList();

    final predictions = await _predictor.predictBatch(inputs);
    final reports = _reportService.getReportsNearby(
      ctx.userLatitude ?? 0,
      ctx.userLongitude ?? 0,
    );

    final scored = <_ScoredRecommendation>[];
    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      final pred = i < predictions.length ? predictions[i] : PredictionResult();
      final routeReports = reports.where((r) => r.routeId == route.routeId).toList();

      double score = _computeScore(pred, route, ctx, routeReports);
      final reason = _generateReason(pred, route, ctx);
      final name = '${route.routeNumber} - ${route.routeName}';

      scored.add(_ScoredRecommendation(
        RouteRecommendation(
          routeId: route.routeId,
          routeNumber: route.routeNumber,
          routeName: name,
          estimatedMinutes: pred.predictedTravelMinutes,
          estimatedFare: pred.predictedFare,
          congestionLevel: pred.congestionLevel,
          recommendationScore: score,
          reason: reason,
          confidence: pred.confidence,
        ),
        score,
      ));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((s) => s.recommendation).toList();
  }

  double _computeScore(
    PredictionResult pred,
    dynamic route,
    RecommendationContext ctx,
    List reports,
  ) {
    double score = 50;

    score += (1.0 - (pred.predictedWaitMinutes / 30)) * 20;
    score += (1.0 - (pred.predictedTravelMinutes / 120)) * 15;

    if (ctx.preferCheapest) {
      score += (1.0 - (pred.predictedFare / 200)) * 20;
    } else if (ctx.preferFastest) {
      score += (1.0 - (pred.predictedTravelMinutes / 120)) * 20;
    } else if (ctx.preferLessCongested) {
      if (pred.congestionLevel == 'low') score += 20;
      else if (pred.congestionLevel == 'medium') score += 10;
    }

    if (ctx.isPeakHour && pred.congestionLevel == 'high') {
      score -= 15;
    }

    if (reports.isNotEmpty) {
      final disruptionCount = reports.length;
      score -= disruptionCount * 5;
    }

    score += pred.confidence * 10;
    score += pred.popularityTrend * 5;

    return score.clamp(0, 100);
  }

  String _generateReason(PredictionResult pred, dynamic route, RecommendationContext ctx) {
    if (pred.congestionLevel == 'low' && pred.predictedTravelMinutes < 30) {
      return 'Quick route with light traffic';
    }
    if (pred.congestionLevel == 'high' && ctx.isPeakHour) {
      return 'Expect delays due to peak hour traffic';
    }
    if (pred.predictedFare < 50) {
      return 'Budget-friendly option';
    }
    if (pred.predictedWaitMinutes <= 3) {
      return 'Frequent matatus available';
    }
    return 'Balanced route option';
  }
}

class _ScoredRecommendation {
  final RouteRecommendation recommendation;
  final double score;
  _ScoredRecommendation(this.recommendation, this.score);
}

class ContextualRecommendationProvider {
  Future<List<RouteRecommendation>> getMorningCommute({
    required String homeStageId,
    required String workStageId,
  }) async {
    final engine = RecommendationEngine();
    final ctx = RecommendationContext(
      fromStageId: homeStageId,
      toStageId: workStageId,
      preferFastest: true,
    );
    return engine.getRecommendations(ctx);
  }

  Future<List<RouteRecommendation>> getEveningCommute({
    required String workStageId,
    required String homeStageId,
  }) async {
    final engine = RecommendationEngine();
    final ctx = RecommendationContext(
      fromStageId: workStageId,
      toStageId: homeStageId,
      preferLessCongested: true,
    );
    return engine.getRecommendations(ctx);
  }

  Future<List<RouteRecommendation>> getBudgetOptions({
    required String fromStageId,
    required String toStageId,
  }) async {
    final engine = RecommendationEngine();
    final ctx = RecommendationContext(
      fromStageId: fromStageId,
      toStageId: toStageId,
      preferCheapest: true,
    );
    return engine.getRecommendations(ctx);
  }
}
