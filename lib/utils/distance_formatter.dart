import 'package:navi_app/models/app_settings.dart';

/// Central distance formatting utility.
///
/// All user-facing distance strings across the app are routed through
/// [format] so that switching the distance unit (km/mi) is applied
/// consistently everywhere.
class DistanceFormatter {
  /// The unit to use when callers do not pass an explicit one.
  ///
  /// Kept in sync with [SettingsService.distanceUnit].
  static DistanceUnit currentUnit = DistanceUnit.km;

  /// Formats a distance in meters for display.
  ///
  /// Metric (km as baseline):
  ///   - under 1000 m          -> "850 m"
  ///   - 1000 m and up         -> "1.5 km"
  /// Imperial (mi):
  ///   - under 0.1 mi (~161 m) -> "320 ft"
  ///   - 0.1 mi and up         -> "1.2 mi"
  static String format(double meters, {DistanceUnit? unit}) {
    final resolved = unit ?? currentUnit;
    if (resolved == DistanceUnit.mi) {
      final miles = meters / 1609.344;
      if (miles >= 0.1) return '${miles.toStringAsFixed(1)} mi';
      return '${(meters / 0.3048).round()} ft';
    }
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  /// Returns the human readable label for a unit, e.g. "Kilometers (km)".
  static String label(DistanceUnit unit) {
    switch (unit) {
      case DistanceUnit.km:
        return 'Kilometers (km)';
      case DistanceUnit.mi:
        return 'Miles (mi)';
    }
  }
}