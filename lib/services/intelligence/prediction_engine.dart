class PredictionInput {
  final String stageId;
  final String stageName;
  final String routeId;
  final String routeNumber;
  final String corridor;
  final int hour;
  final bool isWeekend;
  final bool isPeakHour;

  PredictionInput({
    required this.stageId,
    required this.stageName,
    required this.routeId,
    required this.routeNumber,
    required this.corridor,
    required this.hour,
    this.isWeekend = false,
    this.isPeakHour = false,
  });

  factory PredictionInput.now({
    required String stageId,
    required String stageName,
    required String routeId,
    required String routeNumber,
    required String corridor,
  }) {
    final now = DateTime.now();
    final hour = now.hour;
    final isWeekend = now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday;
    final isPeakHour = (hour >= 6 && hour <= 9) || (hour >= 16 && hour <= 19);
    return PredictionInput(
      stageId: stageId,
      stageName: stageName,
      routeId: routeId,
      routeNumber: routeNumber,
      corridor: corridor,
      hour: hour,
      isWeekend: isWeekend,
      isPeakHour: isPeakHour,
    );
  }
}

class PredictionResult {
  final int predictedWaitMinutes;
  final int predictedTravelMinutes;
  final double predictedFare;
  final String congestionLevel;
  final double popularityTrend;
  final double confidence;

  PredictionResult({
    this.predictedWaitMinutes = 5,
    this.predictedTravelMinutes = 30,
    this.predictedFare = 50.0,
    this.congestionLevel = 'medium',
    this.popularityTrend = 0.5,
    this.confidence = 0.5,
  });
}

class PredictionEngine {
  static final PredictionEngine _instance = PredictionEngine._internal();
  factory PredictionEngine() => _instance;
  PredictionEngine._internal();

  static const _peakMultiplier = 1.5;
  static const _weekendReduction = 0.8;

  Future<PredictionResult> predictWaitTime(PredictionInput input) async {
    final baseWait = _getBaseWaitTime(input);
    final adjusted = _applyFactors(baseWait, input);
    final confidence = _computeConfidence(input);

    return PredictionResult(
      predictedWaitMinutes: adjusted.round(),
      predictedTravelMinutes: _predictTravelTime(input),
      predictedFare: _predictFare(input),
      congestionLevel: _predictCongestion(input),
      popularityTrend: _predictPopularity(input),
      confidence: confidence,
    );
  }

  Future<List<PredictionResult>> predictBatch(List<PredictionInput> inputs) async {
    return Future.wait(inputs.map((input) => predictWaitTime(input)));
  }

  int _predictTravelTime(PredictionInput input) {
    final baseTime = 30;
    final hourFactor = _getHourFactor(input.hour);
    final weekendFactor = input.isWeekend ? _weekendReduction : 1.0;
    return (baseTime * hourFactor * weekendFactor).round();
  }

  double _predictFare(PredictionInput input) {
    final baseFare = 50.0;
    if (input.isPeakHour) return baseFare * _peakMultiplier;
    if (input.isWeekend) return baseFare * 0.9;
    return baseFare;
  }

  String _predictCongestion(PredictionInput input) {
    final hour = input.hour;
    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
      return 'high';
    } else if ((hour >= 6 && hour <= 10) || (hour >= 15 && hour <= 20)) {
      return 'medium';
    }
    return 'low';
  }

  double _predictPopularity(PredictionInput input) {
    final hourScore = _getHourFactor(input.hour);
    final corridorBoost = input.corridor.isNotEmpty ? 0.1 : 0.0;
    return (hourScore + corridorBoost).clamp(0.0, 1.0);
  }

  int _getBaseWaitTime(PredictionInput input) {
    if (input.corridor.contains('Mombasa') ||
        input.corridor.contains('Thika') ||
        input.corridor.contains('Ngong')) {
      return 3;
    }
    return 5;
  }

  double _applyFactors(int base, PredictionInput input) {
    double adjusted = base.toDouble();
    if (input.isPeakHour) adjusted *= _peakMultiplier;
    if (input.isWeekend) adjusted *= _weekendReduction;
    return adjusted;
  }

  double _computeConfidence(PredictionInput input) {
    double base = 0.5;
    if (input.routeId.isNotEmpty) base += 0.2;
    if (input.corridor.isNotEmpty) base += 0.1;
    if (input.isPeakHour) base -= 0.1;
    if (input.isWeekend) base += 0.05;
    return base.clamp(0.1, 0.95);
  }

  double _getHourFactor(int hour) {
    if (hour >= 7 && hour <= 9) return 1.5;
    if (hour >= 12 && hour <= 14) return 1.2;
    if (hour >= 17 && hour <= 19) return 1.6;
    if (hour >= 20 || hour <= 5) return 0.6;
    return 1.0;
  }
}
