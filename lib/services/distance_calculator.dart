import 'package:latlong2/latlong.dart';

import 'package:navi_app/utils/geo_utils.dart';

/// Shared, canonical walking-distance-and-time calculation.
///
/// Every user-facing stage distance in NaVi routes through this one place —
/// the home screen's nearest-stage card, the stage details sheet, and the
/// destination search — so two screens can never disagree about "how far /
/// how long to walk". Distance comes from [haversineDistance] in geo_utils;
/// walking time is derived with the single [kWalkingSpeedMps] constant.
class DistanceCalculator {
  DistanceCalculator._();

  /// Average walking pace, 1.4 m/s (~5 km/h). This is THE walking-speed
  /// constant for commuter walk estimates — do not introduce another.
  static const double kWalkingSpeedMps = 1.4;

  /// Returns the great-circle distance in meters between two coordinates.
  static double distanceMeters(LatLng from, LatLng to) => haversineDistance(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );

  /// Single source of truth for "how far is it and how long do I walk".
  static WalkDistanceResult walkingDistanceAndTime(LatLng from, LatLng to) {
    final meters = distanceMeters(from, to);
    return WalkDistanceResult(
      distanceMeters: meters,
      walkDuration: walkDurationForDistance(meters),
    );
  }

  /// Walking duration in whole seconds for a straight-line distance, using
  /// the single [kWalkingSpeedMps] constant.
  static int walkDurationForDistance(double distanceMeters) =>
      (distanceMeters / kWalkingSpeedMps).round();
}

/// Typed output of [DistanceCalculator.walkingDistanceAndTime].
class WalkDistanceResult {
  final double distanceMeters;
  final int walkDuration;

  const WalkDistanceResult({
    required this.distanceMeters,
    required this.walkDuration,
  });
}