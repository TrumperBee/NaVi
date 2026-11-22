import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../models/active_journey.dart';
import '../../services/polyline_renderer.dart';

/// Route Preview (pre-trip) line styling.
///
/// There is exactly ONE route line style in the app, owned by
/// [PolylineRendererService]: solid mode-blue with a contrasting casing
/// (white by day, near-black at night), 7 dp for the ride and 6 dp for walking
/// legs, with round caps and joins. This builder is a thin, side-effect-free
/// wrapper so widget tests can call it without a map — it must never grow its
/// own dash/colour logic.
class RoutePreviewPolyline {
  const RoutePreviewPolyline._();

  /// Builds the annotations for the whole confirmed journey. Returns an empty
  /// list when there are no real segments yet — the map then shows no line.
  static List<PolylineAnnotationOptions> build(
    ActiveJourney journey, {
    bool isDark = false,
  }) {
    return PolylineRendererService.buildPreviewOptions(journey, isDark: isDark);
  }
}
