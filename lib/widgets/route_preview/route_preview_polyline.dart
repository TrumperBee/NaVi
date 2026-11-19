import 'dart:math' show atan2, cos, min, sin, sqrt;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../models/active_journey.dart';
import '../../models/route_segment.dart';
import '../../services/polyline_renderer.dart';
import 'route_preview_theme.dart';

/// Route Preview (pre-trip) line styling: the ride leg is a solid emerald
/// stroke with a white casing, walking legs are dashed emerald.
///
/// The active-navigation renderer ([PolylineRendererService]) is deliberately
/// left untouched: live guidance keeps its blue ride line, and this builder is
/// a side-effect-free function that widget tests can call directly.
///
/// Dashes are approximated in metres because Mapbox polyline annotations have
/// no dash-array property. 24 m dash / 18 m gap reads as the 6 dp / 6 dp
/// pattern at the zoom used to fit a whole Nairobi journey, and shortens at
/// street-level zoom.
class RoutePreviewPolyline {
  const RoutePreviewPolyline._();

  static const double dashMeters = 24;
  static const double gapMeters = 18;

  /// Builds the annotations for the whole confirmed journey. Returns an empty
  /// list when there are no real segments yet — the map then shows no line.
  static List<PolylineAnnotationOptions> build(ActiveJourney journey) {
    final runs = PolylineRendererService.stitchRuns(
      PolylineRendererService.runsFromSegments(journey.segments),
    );
    final options = <PolylineAnnotationOptions>[];
    for (final run in runs) {
      if (run.coords.length < 2) continue;
      if (run.mode == SegmentMode.matatu) {
        options.add(
          PolylineAnnotationOptions(
            lineColor: RoutePreviewTheme.emerald.toARGB32(),
            lineWidth: RoutePreviewTheme.rideWidth,
            lineOpacity: 1.0,
            lineBorderColor: Colors.white.toARGB32(),
            lineBorderWidth: RoutePreviewTheme.rideCasingWidth,
            lineJoin: LineJoin.ROUND,
            geometry: _toLineString(run.coords),
          ),
        );
      } else {
        options.addAll(_dashedWalk(run.coords));
      }
    }
    return options;
  }

  static List<PolylineAnnotationOptions> _dashedWalk(List<LatLng> coords) {
    if (coords.length < 2) return [];
    final points = List<LatLng>.from(coords);
    final cumulative = <double>[0.0];
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _distanceBetween(points[i - 1], points[i]);
      cumulative.add(total);
    }
    if (total <= 0) return [];

    LatLng pointAt(double distance) {
      for (var i = 1; i < cumulative.length; i++) {
        if (cumulative[i] >= distance) {
          final segmentLength = cumulative[i] - cumulative[i - 1];
          if (segmentLength <= 0) return points[i];
          final t = (distance - cumulative[i - 1]) / segmentLength;
          return _interpolate(points[i - 1], points[i], t);
        }
      }
      return points.last;
    }

    final dashes = <PolylineAnnotationOptions>[];
    var cursor = 0.0;
    while (cursor < total) {
      final dashEnd = min(cursor + dashMeters, total);
      if (dashEnd - cursor > 1.0) {
        dashes.add(
          PolylineAnnotationOptions(
            lineColor: RoutePreviewTheme.emerald.toARGB32(),
            lineWidth: RoutePreviewTheme.walkWidth,
            lineOpacity: 1.0,
            lineJoin: LineJoin.ROUND,
            geometry: _toLineString([pointAt(cursor), pointAt(dashEnd)]),
          ),
        );
      }
      cursor = dashEnd + gapMeters;
    }
    return dashes;
  }

  static LatLng _interpolate(LatLng a, LatLng b, double t) => LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  static double _distanceBetween(LatLng a, LatLng b) {
    const double r = 6371000;
    final dLat = (b.latitude - a.latitude) * 3.14159265359 / 180;
    final dLng = (b.longitude - a.longitude) * 3.14159265359 / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * 3.14159265359 / 180) *
            cos(b.latitude * 3.14159265359 / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return 2 * r * atan2(sqrt(h), sqrt(1 - h));
  }

  static LineString _toLineString(List<LatLng> points) => LineString.fromJson({
        'type': 'LineString',
        'coordinates':
            points.map((point) => [point.longitude, point.latitude]).toList(),
      });
}
