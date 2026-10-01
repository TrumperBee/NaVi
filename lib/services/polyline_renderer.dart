import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/features/map/mapbox_map_manager.dart';

/// A run of consecutive coordinates sharing one transport mode. Runs are the
/// renderer's unit of drawing: consecutive same-mode segments are stitched
/// into one annotation so the route never reads as two disconnected pieces.
class PolylineSegmentRun {
  final SegmentMode mode;
  final List<LatLng> coords;

  const PolylineSegmentRun({required this.mode, required this.coords});
}

/// Renders the journey polyline as high-contrast, per-mode annotations:
/// walking legs are DASHED GREEN, matatu legs are SOLID BLUE.
///
/// [renderJourney] with [preview] = true renders the full confirmed route
/// (used by the pre-trip overview); the non-preview mode keeps the
/// progressive traveled/remaining styling used during live navigation.
///
/// All legs are stitched into one continuous chain: the last coordinate of a
/// segment is snapped onto the first coordinate of the next, and every
/// annotation uses ROUND caps/joins so walk → matatu → walk transitions read
/// as ONE line, not two separate segments.
class PolylineRendererService {
  final MapboxMapManager _mapManager;

  /// High-contrast walk line. Distinct from the transit brand green so the
  /// dashed walk and the blue matatu ride never both read as one line.
  static const Color _walkColor = Color(0xFF00875A);
  static const Color _rideColor = Color(0xFF1E88E5);

  PolylineRendererService(this._mapManager);

  Future<void> initialize() async {}

  Future<void> renderJourney(ActiveJourney journey, {bool preview = false}) async {
    final options = preview
        ? buildPreviewOptions(journey)
        : buildLiveOptions(journey);
    await _mapManager.setPolylineAnnotations(options);
  }

  Future<void> updateCurrentSegment(ActiveJourney journey) async {
    await _mapManager.setPolylineAnnotations(buildLiveOptions(journey));
  }

  Future<void> clearJourney() async {
    await _mapManager.setPolylineAnnotations([]);
  }

  /// Static, side-effect-free preview options — testable without a map.
  static List<PolylineAnnotationOptions> buildPreviewOptions(
      ActiveJourney journey) {
    return _optionsForRuns(
      stitchRuns(runsFromSegments(journey.segments)),
      remainingOpacity: 0.95,
    );
  }

  /// Static, side-effect-free live options (progressively dimmed traveled
  /// path + remaining route) — testable without a map.
  static List<PolylineAnnotationOptions> buildLiveOptions(
      ActiveJourney journey) {
    final options = <PolylineAnnotationOptions>[];

    final traveledCoords = journey.getTraveledCoordinates();
    if (traveledCoords.length >= 2) {
      options.add(PolylineAnnotationOptions(
        lineColor: Colors.grey.toARGB32(),
        lineWidth: 3.0,
        lineOpacity: 0.5,
        lineJoin: LineJoin.ROUND,
        geometry: _toLineString(traveledCoords),
      ));
    }

    // Build the remaining route as a single mode-run chain so the current
    // segment, upcoming segments and transfer walks all connect visually.
    final remainingRuns = <PolylineSegmentRun>[];
    final current = journey.currentSegment;
    final currentRemaining = journey.getCurrentSegmentRemainingCoordinates();
    if (current != null && currentRemaining.isNotEmpty) {
      remainingRuns.add(
          PolylineSegmentRun(mode: current.mode, coords: currentRemaining));
    }
    for (final segment in journey.upcomingSegments) {
      remainingRuns.add(
          PolylineSegmentRun(mode: segment.mode, coords: segment.coordinates));
    }
    options.addAll(_optionsForRuns(
      stitchRuns(remainingRuns),
      remainingOpacity: 0.95,
    ));

    return options;
  }

  /// Converts a list of stitched runs into concrete annotations: solid blue
  /// for matatu legs, dashed green for walk legs. All annotations use rounded
  /// caps/joins so neighbouring legs blend into one continuous line.
  static List<PolylineAnnotationOptions> _optionsForRuns(
    List<PolylineSegmentRun> runs, {
    required double remainingOpacity,
  }) {
    final options = <PolylineAnnotationOptions>[];
    for (final run in runs) {
      if (run.coords.length < 2) continue;
      if (run.mode == SegmentMode.matatu) {
        options.add(PolylineAnnotationOptions(
          lineColor: _rideColor.toARGB32(),
          lineWidth: 6.0,
          lineOpacity: remainingOpacity,
lineBorderColor: Colors.white.toARGB32(),
        lineBorderWidth: 1.5,
        lineJoin: LineJoin.ROUND,
        geometry: _toLineString(run.coords),
      ));
      } else {
        options.addAll(
            _dashedWalk(run.coords, opacity: remainingOpacity));
      }
    }
    return options;
  }

  /// Converts a list of segments into a list of same-mode runs (first pass;
  /// consecutive same-mode segments remain separate runs to be merged by
  /// [stitchRuns]).
  static List<PolylineSegmentRun> runsFromSegments(List<RouteSegment> segments) {
    return [
      for (final segment in segments)
        if (segment.coordinates.isNotEmpty)
          PolylineSegmentRun(mode: segment.mode, coords: segment.coordinates),
    ];
  }

  /// Stitches a sequence of runs into a single continuous chain of same-mode
  /// runs. Each run's start is snapped to the previous run's end so there is
  /// never a gap at a boarding stage / transfer point, and consecutive
  /// same-mode neighbours are merged into one annotation.
  static List<PolylineSegmentRun> stitchRuns(List<PolylineSegmentRun> runs) {
    final result = <PolylineSegmentRun>[];
    for (final run in runs) {
      if (run.coords.isEmpty) continue;

      if (result.isNotEmpty) {
        final last = result.last;
        final anchor = last.coords.last;
        if (last.mode == run.mode) {
          // Same mode: merge coordinates, dropping the duplicated junction
          // point so the polyline is truly continuous.
          final merged = List<LatLng>.of(last.coords);
          merged.addAll(run.coords.first == anchor ? run.coords.skip(1) : run.coords);
          result[result.length - 1] = PolylineSegmentRun(mode: run.mode, coords: merged);
        } else {
          // Mode change: snap the new run's start onto the previous end.
          result.add(PolylineSegmentRun(
            mode: run.mode,
            coords: run.coords.first == anchor
                ? run.coords
                : [anchor, ...run.coords],
          ));
        }
      } else {
        result.add(run);
      }
    }
    return result;
  }

  /// Splits a walking segment into short high-contrast dashes (the Mapbox
  /// polyline annotation API has no dash-array, so dashed legs are emulated).
  /// Dashes always end exactly at the leg's endpoint so they meet the next
  /// (matatu) leg at the junction point.
  static List<PolylineAnnotationOptions> _dashedWalk(
    List<LatLng> coords, {
    double opacity = 0.95,
    double dashMeters = 18,
    double gapMeters = 9,
  }) {
    if (coords.length < 2) return [];
    final pts = List<LatLng>.from(coords);
    final cumulative = <double>[];
    double acc = 0.0;
    cumulative.add(0.0);
    for (int i = 1; i < pts.length; i++) {
      acc += _distanceBetween(pts[i - 1], pts[i]);
      cumulative.add(acc);
    }
    final total = acc;
    if (total <= 0) return [];

    LatLng pointAt(double d) {
      for (int i = 1; i < cumulative.length; i++) {
        if (cumulative[i] >= d) {
          final segLen = cumulative[i] - cumulative[i - 1];
          if (segLen <= 0) return pts[i];
          final t = (d - cumulative[i - 1]) / segLen;
          return _interpolate(pts[i - 1], pts[i], t);
        }
      }
      return pts.last;
    }

    final dashes = <PolylineAnnotationOptions>[];
    double cursor = 0.0;
    while (cursor < total) {
      final dashEnd = min(cursor + dashMeters, total);
      if (dashEnd - cursor > 1.0) {
        dashes.add(PolylineAnnotationOptions(
          lineColor: _walkColor.toARGB32(),
          lineWidth: 4.5,
          lineOpacity: opacity,
          lineBorderColor: Colors.white.toARGB32(),
          lineBorderWidth: 1.0,
          lineJoin: LineJoin.ROUND,
          geometry: _toLineString([pointAt(cursor), pointAt(dashEnd)]),
        ));
      }
      cursor = dashEnd + gapMeters;
    }
    return dashes;
  }

  static LatLng _interpolate(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  static double _distanceBetween(LatLng a, LatLng b) {
    const double R = 6371000;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * pi / 180) * cos(b.latitude * pi / 180) *
            sin(dLng / 2) * sin(dLng / 2);
    return 2 * atan2(sqrt(h), sqrt(1 - h)) * R;
  }

  static LineString _toLineString(List<LatLng> points) =>
      LineString.fromJson({
        'type': 'LineString',
        'coordinates': points.map((p) => [p.longitude, p.latitude]).toList(),
      });
}