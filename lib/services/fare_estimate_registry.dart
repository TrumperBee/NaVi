import 'package:navi_app/models/fare_estimate_record.dart';

/// In-memory store of contributor-reported fare estimates (spec §1.6).
///
/// Mirrors the `PlaceRegistry`/`StageRegistry` shape exactly: a static,
/// swappable universe with a safe swap-on-load and, here, an empty default —
/// fares are contributor-sourced, so the computed `FareCalculatorService`
/// value is the universal default until someone reports and a reviewer
/// verifies a real-world fare.
///
/// Resolution rule (enforced here, consumed by `FareCalculatorService`):
/// only a row with `FareConfidence.verified` participates in what a user
/// sees. Unverified rows exist in the store for the review UI but never
/// override the computed value.
class FareEstimateRegistry {
  FareEstimateRegistry._();

  static List<FareEstimateRecord> _estimates = const [];

  /// Active estimate list (unmodifiable).
  static List<FareEstimateRecord> get all => List.unmodifiable(_estimates);

  /// Replaces the active list. The swap is ignored when [estimates] is empty
  /// so a failed load never silently wipes already-loaded reports.
  static void setEstimates(List<FareEstimateRecord> estimates) {
    if (estimates.isNotEmpty) {
      _estimates = List.unmodifiable(estimates);
    }
  }

  /// Resets the store (test teardown / account switch). Unlike [setEstimates],
  /// an empty reset is legitimate and honoured.
  static void clear() {
    _estimates = const [];
  }

  /// Verified row for the exact §1.6 tuple, or null. This is the only lookup
  /// the display/resolution path may use. A store with no row for the tuple —
  /// or only unverified/disputed rows — yields null so callers fall back to
  /// the computed value.
  static FareEstimateRecord? findVerified(
    String routeId,
    String fromStageId,
    String toStageId,
  ) {
    for (final estimate in _estimates) {
      if (estimate.confidence == FareConfidence.verified &&
          estimate.routeId == routeId &&
          estimate.fromStageId == fromStageId &&
          estimate.toStageId == toStageId) {
        return estimate;
      }
    }
    return null;
  }

  /// Any row for the tuple regardless of confidence — the review path, which
  /// must be able to see unverified submissions before they are promoted.
  static FareEstimateRecord? findAny(
    String routeId,
    String fromStageId,
    String toStageId,
  ) {
    for (final estimate in _estimates) {
      if (estimate.routeId == routeId &&
          estimate.fromStageId == fromStageId &&
          estimate.toStageId == toStageId) {
        return estimate;
      }
    }
    return null;
  }

  /// Inserts a row, or replaces the existing row for the same tuple (a
  /// re-report of the same leg supersedes — one fare per tuple, not per
  /// submission). A later re-submission naturally re-enters review as the
  /// confidence the submitter raised it with (unverified is inert at display
  /// time, so a downgrade can never regress what a user sees).
  static void upsert(FareEstimateRecord record) {
    final existingIndex =
        _estimates.indexWhere((e) => e.key == record.key);
    if (existingIndex >= 0) {
      final updated = <FareEstimateRecord>[..._estimates];
      updated[existingIndex] = record;
      _estimates = List.unmodifiable(updated);
    } else {
      _estimates = List.unmodifiable([..._estimates, record]);
    }
  }

  /// Reviewer gate (spec §6.4: Verified is system-set during review): promotes
  /// the stored row for this tuple to verified and stamps [verifiedAt]. No-op
  /// when no row exists for the tuple.
  static void markVerified({
    required String routeId,
    required String fromStageId,
    required String toStageId,
    DateTime? verifiedAt,
  }) {
    final existing = findAny(routeId, fromStageId, toStageId);
    if (existing == null) return;
    upsert(existing.copyWith(
      confidence: FareConfidence.verified,
      lastVerified: verifiedAt ?? DateTime.now(),
    ));
  }
}