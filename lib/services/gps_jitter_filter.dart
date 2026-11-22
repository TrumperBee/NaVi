import 'package:latlong2/latlong.dart' hide DistanceCalculator;

import 'distance_calculator.dart';

/// Drops GPS fixes that are closer than [minimumDistanceMeters] to the last
/// accepted fix.
///
/// The geolocator stream already asks the platform for a 5 m distance filter,
/// but a stationary device can still oscillate across that threshold. Keeping
/// the same threshold here makes the smoothing explicit and testable, and
/// stops tiny fixes from repainting the live puck/progress UI.
class GpsJitterFilter {
  static const double defaultMinimumDistanceMeters = 5;

  final double minimumDistanceMeters;
  LatLng? _lastAccepted;

  GpsJitterFilter({
    this.minimumDistanceMeters = defaultMinimumDistanceMeters,
  });

  LatLng? get lastAccepted => _lastAccepted;

  /// Seeds the filter without emitting a fix (used for the initial GPS lock so
  /// the first streamed fix within 5 m is treated as jitter).
  void seed(LatLng point) {
    _lastAccepted = LatLng(point.latitude, point.longitude);
  }

  void reset() {
    _lastAccepted = null;
  }

  /// Returns true only when [candidate] should be applied. Exactly
  /// [minimumDistanceMeters] is accepted; only smaller moves are ignored.
  bool shouldAccept(LatLng candidate) {
    final last = _lastAccepted;
    if (last == null) {
      seed(candidate);
      return true;
    }
    if (DistanceCalculator.distanceMeters(last, candidate) <
        minimumDistanceMeters) {
      return false;
    }
    seed(candidate);
    return true;
  }
}
