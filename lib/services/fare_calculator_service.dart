import 'package:navi_app/models/fare_estimate.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/data/fare_matrix_seed.dart';
import 'package:navi_app/data/nairobi_corridors_seed.dart';
import 'package:navi_app/services/fare_estimate_registry.dart';

class FareCalculatorService {
  static const double _baseWalkSpeed = 5.0; // km/h

  static FareEstimate calculateFare(RouteSegment segment, {DateTime? atTime}) {
    if (segment.mode == SegmentMode.walk) {
      return FareEstimate.walking(
        timeOfDay: FareMatrix.getTimeOfDay(atTime ?? DateTime.now()),
      );
    }

    final timeOfDay = FareMatrix.getTimeOfDay(atTime ?? DateTime.now());
    final tier = _getCorridorTier(segment.routeNumber ?? '');

    // §1.6 resolution order (override layer): a VERIFIED contributor-reported
    // fare for this exact (route, from, to) tuple wins over the computed
    // value. The computed estimate remains the default for everything else.
    // Unverified rows are stored but must never reach a user, so the lookup
    // only surfaces verified ones — and only when the reported amount is a
    // sane positive fare (the same "never show a 0 matatu fare" rule as the
    // computed path).
    final verified = _verifiedEstimateOverride(segment, timeOfDay);
    if (verified != null) {
      return FareEstimate.matatu(
        amountKsh: verified,
        tier: tier,
        timeOfDay: timeOfDay,
      );
    }

    final fareRange = FareMatrix.getFareRange(tier, timeOfDay);
    final baseFare = _calculateBaseFare(tier, fareRange, segment.distanceMeters);

    var roundedFare = FareMatrix.roundToStandardDenomination(baseFare);

    // HARD RULE: a matatu leg is never free. Walking is the only free mode.
    // If the bracket ever produced a zero (or a faulty range did), fall back
    // to the minimum standard fare for the tier so a "free matatu ride" can
    // never be shown to the user.
    if (roundedFare <= 0) {
      final fallbackMin = fareRange.isNotEmpty
          ? FareMatrix.roundToStandardDenomination(fareRange.first)
          : 20;
      roundedFare = fallbackMin <= 0 ? 20 : fallbackMin;
    }

    return FareEstimate.matatu(
      amountKsh: roundedFare,
      tier: tier,
      timeOfDay: timeOfDay,
    );
  }

  /// New §1.6 read path: the only place a `fare_estimates` row may reach a
  /// user. Returns null (→ computed fallback) unless every gate passes:
  /// the leg has staged boundaries, a verified row exists for the exact
  /// tuple, and the period's reported amount is a positive standard fare.
  static int? _verifiedEstimateOverride(
    RouteSegment segment,
    TimeOfDay timeOfDay,
  ) {
    final from = segment.fromStageId;
    final to = segment.toStageId;
    final route = segment.routeNumber;
    if (from == null || to == null || route == null || route.isEmpty) {
      return null;
    }

    final estimate = FareEstimateRegistry.findVerified(route, from, to);
    if (estimate == null) return null;

    final amount = timeOfDay == TimeOfDay.peak
        ? estimate.estimatedPeak
        : estimate.estimatedOffpeak;
    if (amount <= 0) return null;

    return amount;
  }

  static int calculateJourneyTotal(List<RouteSegment> segments, {DateTime? atTime}) {
    int total = 0;
    for (final segment in segments) {
      total += calculateFare(segment, atTime: atTime).amountKsh;
    }
    return total;
  }

  static FareTier _getCorridorTier(String routeNumber) {
    for (final corridor in nairobiCorridors.values) {
      if (corridor.routeNumbers.contains(routeNumber)) {
        return corridor.fareTier;
      }
    }
    return FareTier.medium;
  }

  static int _calculateBaseFare(FareTier tier, List<int> fareRange, double distanceMeters) {
    final distanceKm = distanceMeters / 1000.0;
    final minFare = fareRange.first.toDouble();
    final maxFare = fareRange.last.toDouble();

    switch (tier) {
      case FareTier.short:
        return minFare.round();
      case FareTier.medium:
        return ((minFare + (maxFare - minFare) * (distanceKm / 15.0)).clamp(minFare, maxFare)).round();
      case FareTier.long:
        return maxFare.round();
    }
  }

  static FareTier getCorridorTierForRoute(String routeNumber) {
    return _getCorridorTier(routeNumber);
  }
}