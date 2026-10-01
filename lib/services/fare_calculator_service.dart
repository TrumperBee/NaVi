import 'package:navi_app/models/fare_estimate.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/data/fare_matrix_seed.dart';
import 'package:navi_app/data/nairobi_corridors_seed.dart';

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