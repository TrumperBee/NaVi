import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import 'package:navi_app/design/navi_colors.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/services/distance_calculator.dart';
import 'package:navi_app/features/map/mapbox_map_manager.dart';

/// A run of consecutive coordinates sharing one transport mode. Runs are the
/// renderer's unit of drawing: consecutive same-mode segments are stitched
/// into one annotation so the route never reads as two disconnected pieces.
class PolylineSegmentRun {
  final SegmentMode mode;
  final List<LatLng> coords;

  const PolylineSegmentRun({required this.mode, required this.coords});
}

/// Renders the journey polyline as ONE solid route style.
///
/// Both ride and walking legs use the mode's route blue (light `#1A73E8`,
/// dark `#4C8DF6`) over a contrasting casing (light white, dark `#12161C`):
/// 7 dp for the ride and 6 dp for walks, with round caps and joins. Mapbox's
/// annotation options expose width but not a dash array, so walk vs ride is
/// communicated by weight, not by a fake dash pattern.
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
  /// Route line weight, ride leg (dp).
  static const double rideWidth = 7.0;

  /// Route line weight, walking leg (dp).
  static const double walkWidth = 6.0;

  /// The casing under every route line is this much wider than the line.
  static const double casingExtraWidth = 4.0;

  final MapboxMapManager _mapManager;

  /// Whether the night map style is up. Set by the owning screen on every
  /// build so theme switches repaint the line without a map rebuild.
  bool isDark;

  PolylineRendererService(this._mapManager, {this.isDark = false});

  /// Route blue: the light-mode tone by day, the lifted tone at night.
  static Color routeColorFor(bool isDark) =>
      isDark ? NaviColors.routeBlueDark : NaviColors.routeBlue;

  /// Casing under the route line. White on the day map, near-black on the
  /// night map so the direction stays legible in both themes.
  static Color casingColorFor(bool isDark) =>
      isDark ? NaviColors.routeCasingDark : NaviColors.routeCasingLight;

  Future<void> initialize() async {}

  Future<void> renderJourney(
    ActiveJourney journey, {
    bool preview = false,
    bool? isDark,
    bool navigationLine = false,
    String? debugEvent,
  }) async {
    final dark = isDark ?? this.isDark;
    final options = preview
        ? buildPreviewOptions(journey, isDark: dark)
        : buildLiveOptions(journey, isDark: dark);
    _logHandoff(debugEvent, options);
    await _mapManager.setPolylineAnnotations(options,
        navigationLine: navigationLine);
  }

  Future<void> updateCurrentSegment(
    ActiveJourney journey, {
    String debugEvent = 'gps_update',
  }) async {
    final options = buildLiveOptions(journey, isDark: isDark);
    _logHandoff(debugEvent, options);
    await _mapManager.setPolylineAnnotations(options, navigationLine: true);
  }

  Future<void> clearJourney() async {
    await _mapManager.setPolylineAnnotations([], navigationLine: true);
  }

  /// STEP 0 diagnostic, kept in debug builds: reports the exact point counts
  /// handed to Mapbox on the first live frame and after every GPS fix, so a
  /// disappearing line can be traced without a device attached.
  static void _logHandoff(
      String? event, List<PolylineAnnotationOptions> options) {
    if (event == null || !kDebugMode) return;
    final lines = options.map((option) {
      final coordinates = option.geometry.coordinates
          .map((point) => '(${point.lat}, ${point.lng})')
          .join(' -> ');
      return '${option.lineWidth}dp $coordinates';
    }).join(' | ');
    debugPrint('[ACTIVE_NAV_LINE] $event options=${options.length} $lines');
  }

  /// Static, side-effect-free preview options — testable without a map.
  static List<PolylineAnnotationOptions> buildPreviewOptions(
    ActiveJourney journey, {
    bool isDark = false,
  }) {
    return _optionsForRuns(
      stitchRuns(runsFromSegments(journey.segments)),
      isDark: isDark,
    );
  }

  /// Static, side-effect-free live options (progressively dimmed traveled
  /// path + remaining route) — testable without a map.
  static List<PolylineAnnotationOptions> buildLiveOptions(
    ActiveJourney journey, {
    bool isDark = false,
  }) {
    final options = <PolylineAnnotationOptions>[];

    final traveledCoords = journey.getTraveledCoordinates();
    if (traveledCoords.length >= 2) {
      options.add(PolylineAnnotationOptions(
        lineColor: Colors.grey.toARGB32(),
        lineWidth: 4.0,
        lineOpacity: 0.5,
        lineJoin: LineJoin.ROUND,
        geometry: _toLineString(traveledCoords),
      ));
    }

    // Build the remaining route as one mode-run chain from the user's live
    // position forward. Every leg is included; only geometry already behind
    // the traveller is dropped.
    options.addAll(_optionsForRuns(
      remainingRuns(journey),
      isDark: isDark,
    ));

    return options;
  }

  /// All not-yet-travelled geometry, stitched into contiguous same-mode runs.
  ///
  /// The current leg starts at the GPS point itself (snapped to the nearest
  /// route vertex) rather than two vertices behind it, so the blue line never
  /// extends back through already-walked geometry.
  static List<PolylineSegmentRun> remainingRuns(ActiveJourney journey) {
    final runs = <PolylineSegmentRun>[];
    final current = journey.currentSegment;
    final currentRemaining = remainingCoordinatesFromUser(journey);
    if (current != null && currentRemaining.length >= 2) {
      runs.add(
          PolylineSegmentRun(mode: current.mode, coords: currentRemaining));
    }
    for (final segment in journey.upcomingSegments) {
      if (segment.coordinates.length >= 2) {
        runs.add(PolylineSegmentRun(
            mode: segment.mode, coords: segment.coordinates));
      }
    }
    return stitchRuns(runs);
  }

  /// Current-leg coordinates from the traveller forward, with the GPS point as
  /// the first vertex. Used by both the renderer and the camera framer so the
  /// line and the "next 300 m" viewport start from the same place.
  static List<LatLng> remainingCoordinatesFromUser(ActiveJourney journey) {
    final segment = journey.currentSegment;
    if (segment == null || segment.coordinates.isEmpty) return const [];
    final coords = segment.coordinates;
    final position = journey.currentPosition;
    if (position == null) return List<LatLng>.of(coords);
    if (coords.length == 1) return [position, coords.single];

    // Project the GPS fix onto the nearest polyline *segment*, not the nearest
    // vertex. Snapping to a vertex can point the blue line back down geometry
    // the traveller has already covered whenever the closer vertex happens to
    // sit behind them.
    final latitudeScale =
        math.cos(position.latitude * math.pi / 180).abs().clamp(0.01, 1.0);
    var bestIndex = 0;
    var bestT = 0.0;
    var bestDistance = double.infinity;
    for (var i = 0; i < coords.length - 1; i++) {
      final a = coords[i];
      final b = coords[i + 1];
      final dx = (b.longitude - a.longitude) * latitudeScale;
      final dy = b.latitude - a.latitude;
      final px = (position.longitude - a.longitude) * latitudeScale;
      final py = position.latitude - a.latitude;
      final denominator = dx * dx + dy * dy;
      final t = denominator == 0
          ? 0.0
          : ((px * dx + py * dy) / denominator).clamp(0.0, 1.0);
      final projected = _interpolate(a, b, t);
      final distance = DistanceCalculator.distanceMeters(position, projected);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
        bestT = t;
      }
    }

    // Keep the far end of the segment we are on, then every later vertex. If
    // the fix is already at that far end, skip it and continue from the next.
    final firstAhead = bestT < 0.999 ? bestIndex + 1 : bestIndex + 2;
    final result = <LatLng>[];
    void add(LatLng point) {
      if (result.isEmpty ||
          DistanceCalculator.distanceMeters(result.last, point) > 0.01) {
        result.add(point);
      }
    }

    add(position);
    for (var i = firstAhead; i < coords.length; i++) {
      add(coords[i]);
    }
    // A two-point line is still needed for the final approach to destination.
    if (result.length == 1) result.add(coords.last);
    return result;
  }

  /// Geometry for route-ahead camera framing, capped at [meters] instead of
  /// using the whole remaining journey (which can be several kilometres).
  static List<LatLng> pointsAhead(
    ActiveJourney journey, {
    double meters = 300,
  }) {
    final result = <LatLng>[];
    var covered = 0.0;

    outer:
    for (final run in remainingRuns(journey)) {
      final coords = run.coords;
      if (coords.isEmpty) continue;
      if (result.isEmpty) result.add(coords.first);
      for (var i = 1; i < coords.length; i++) {
        final from = coords[i - 1];
        final to = coords[i];
        final segmentLength = DistanceCalculator.distanceMeters(from, to);
        if (covered + segmentLength >= meters) {
          if (segmentLength > 0) {
            final fraction =
                ((meters - covered) / segmentLength).clamp(0.0, 1.0);
            result.add(_interpolate(from, to, fraction));
          }
          break outer;
        }
        covered += segmentLength;
        result.add(to);
      }
    }
    return result;
  }

  static LatLng _interpolate(LatLng from, LatLng to, double t) => LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );

  /// Converts stitched runs into solid route annotations. Walking runs are
  /// emitted first so the heavier ride stroke stays on top where the two meet.
  static List<PolylineAnnotationOptions> _optionsForRuns(
    List<PolylineSegmentRun> runs, {
    required bool isDark,
  }) {
    final routeColor = routeColorFor(isDark);
    final casingColor = casingColorFor(isDark);
    final options = <PolylineAnnotationOptions>[];
    for (final mode in const [SegmentMode.walk, SegmentMode.matatu]) {
      for (final run in runs) {
        if (run.coords.length < 2 || run.mode != mode) continue;
        options.add(PolylineAnnotationOptions(
          lineColor: routeColor.toARGB32(),
          lineWidth: mode == SegmentMode.matatu ? rideWidth : walkWidth,
          lineOpacity: 1.0,
          // The border is drawn under the fill, so this is the mode casing.
          lineBorderColor: casingColor.toARGB32(),
          lineBorderWidth: casingExtraWidth,
          lineJoin: LineJoin.ROUND,
          geometry: _toLineString(run.coords),
        ));
      }
    }
    return options;
  }

  /// Converts a list of segments into a list of same-mode runs (first pass;
  /// consecutive same-mode segments remain separate runs to be merged by
  /// [stitchRuns]).
  static List<PolylineSegmentRun> runsFromSegments(
      List<RouteSegment> segments) {
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
          merged.addAll(
              run.coords.first == anchor ? run.coords.skip(1) : run.coords);
          result[result.length - 1] =
              PolylineSegmentRun(mode: run.mode, coords: merged);
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

  /// Geometry is passed through exactly as resolved (Mapbox `overview=full`),
  /// with no decimation, so every corner that is closer than 5 m apart is
  /// still drawn.
  static LineString _toLineString(List<LatLng> points) => LineString.fromJson({
        'type': 'LineString',
        'coordinates': points.map((p) => [p.longitude, p.latitude]).toList(),
      });
}
