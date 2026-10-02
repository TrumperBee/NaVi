/// A contributor-reported real-world fare for one (route, from stage, to
/// stage) pair, per the transport data spec §1.6.
///
/// These are the OVERRIDE layer of NaVi's two fare mechanisms: the computed
/// `FareCalculatorService` estimate is the always-available default, and a
/// verified row here wins for the exact tuple it covers. An UNVERIFIED row
/// exists in the store for review but never affects what a user sees.
///
/// Note on `routeId`: the spec field is `route_id`. In this app the journey
/// path carries route identity as the painted route NUMBER (there is no
/// `RouteRegistry`, and `RouteSegment` only knows `routeNumber`), so rows
/// covering GTFS-sourced journeys store that number here (e.g. "34B"). The
/// field is a plain identifier; what matters is that display-time resolution
/// matches on exactly what the journey carries. This is documented bridging,
/// not a schema deviation.
class FareEstimateRecord {
  final String routeId;
  final String fromStageId;
  final String toStageId;
  final int estimatedOffpeak;
  final int estimatedPeak;

  /// §6 confidence semantics, shared with places/stages: only [FareConfidence
  /// .verified] participates in resolution.
  final FareConfidence confidence;

  /// When this estimate was verified (for rows still unverified: the time the
  /// fare was observed/reported — kept non-null per the §1.6 required column).
  final DateTime lastVerified;

  /// Contributor/user attribution for trust scoring.
  final String? reportedBy;

  const FareEstimateRecord({
    required this.routeId,
    required this.fromStageId,
    required this.toStageId,
    required this.estimatedOffpeak,
    required this.estimatedPeak,
    this.confidence = FareConfidence.unverified,
    required this.lastVerified,
    this.reportedBy,
  });

  /// Natural key: the exact tuple resolution is keyed on.
  String get key => '$routeId|$fromStageId|$toStageId';

  /// The fare shown at a given period — the only amount the resolution order
  /// is ever allowed to surface for this row.
  int amountAt(bool isPeak) => isPeak ? estimatedPeak : estimatedOffpeak;

  Map<String, dynamic> toMap() => {
        'route_id': routeId,
        'from_stage_id': fromStageId,
        'to_stage_id': toStageId,
        'estimated_offpeak': estimatedOffpeak,
        'estimated_peak': estimatedPeak,
        'confidence': confidence.name,
        'last_verified': lastVerified.toIso8601String(),
        'reported_by': reportedBy,
      };

  factory FareEstimateRecord.fromMap(Map<String, dynamic> map) {
    return FareEstimateRecord(
      routeId: map['route_id'] ?? map['routeId'] ?? '',
      fromStageId: map['from_stage_id'] ?? map['fromStageId'] ?? '',
      toStageId: map['to_stage_id'] ?? map['toStageId'] ?? '',
      estimatedOffpeak: (map['estimated_offpeak'] ?? map['estimatedOffpeak'] ?? 0).toInt(),
      estimatedPeak: (map['estimated_peak'] ?? map['estimatedPeak'] ?? 0).toInt(),
      confidence: _parseConfidence(map['confidence']),
      lastVerified: map['last_verified'] != null
          ? DateTime.parse(map['last_verified'])
          : DateTime.now(),
      reportedBy: map['reported_by'] as String?,
    );
  }

  static FareConfidence _parseConfidence(dynamic raw) {
    if (raw is FareConfidence) return raw;
    if (raw is String) {
      for (final value in FareConfidence.values) {
        if (value.name == raw) return value;
      }
    }
    return FareConfidence.unverified;
  }

  FareEstimateRecord copyWith({
    int? estimatedOffpeak,
    int? estimatedPeak,
    FareConfidence? confidence,
    DateTime? lastVerified,
    String? reportedBy,
  }) {
    return FareEstimateRecord(
      routeId: routeId,
      fromStageId: fromStageId,
      toStageId: toStageId,
      estimatedOffpeak: estimatedOffpeak ?? this.estimatedOffpeak,
      estimatedPeak: estimatedPeak ?? this.estimatedPeak,
      confidence: confidence ?? this.confidence,
      lastVerified: lastVerified ?? this.lastVerified,
      reportedBy: reportedBy ?? this.reportedBy,
    );
  }

  @override
  String toString() =>
      'FareEstimateRecord($key, offpeak: $estimatedOffpeak, peak: '
      '$estimatedPeak, ${confidence.name})';
}

/// §6 confidence, identical values to the place/stage confidence enums so a
/// reviewer treats all three entities the same way.
enum FareConfidence { verified, unverified, disputed }