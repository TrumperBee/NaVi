import 'package:latlong2/latlong.dart';

/// Immutable endpoint anchors for a confirmed journey.
///
/// Only the departure is stored here: it is the coordinate the journey was
/// planned from and must never follow the live GPS puck. `TripMarkerAnchors`
/// accepts the first value after a clear and ignores every later write until
/// [clear] is called for the next journey.
class TripMarkerAnchors {
  LatLng? _departure;

  LatLng? get departure => _departure;

  /// Stores [point] only if no departure is held yet.
  ///
  /// Returns true when the anchor changed, so callers can notify listeners only
  /// on a real state change.
  bool confirmDeparture(LatLng point) {
    if (_departure != null) return false;
    _departure = LatLng(point.latitude, point.longitude);
    return true;
  }

  /// Clears the anchor when a new journey starts being planned.
  bool clear() {
    if (_departure == null) return false;
    _departure = null;
    return true;
  }

  /// Stable identity for redraw decisions. Deliberately independent of live
  /// GPS fixes.
  String get key {
    final point = _departure;
    if (point == null) return 'none';
    return '${point.latitude.toStringAsFixed(6)},'
        '${point.longitude.toStringAsFixed(6)}';
  }
}
