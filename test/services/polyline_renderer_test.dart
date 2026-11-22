import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/design/navi_colors.dart';
import 'package:navi_app/services/distance_calculator.dart' as nav_distance;
import 'package:navi_app/services/polyline_renderer.dart';
import 'package:test/test.dart';

void main() {
  group('stitchRuns', () {
    test('merges consecutive same-mode runs into one continuous run', () {
      const a = LatLng(-1.2833, 36.8167);
      const b = LatLng(-1.2850, 36.8183);
      const c = LatLng(-1.2875, 36.8200);

      final stitched = PolylineRendererService.stitchRuns([
        const PolylineSegmentRun(mode: SegmentMode.walk, coords: [a, b]),
        const PolylineSegmentRun(mode: SegmentMode.walk, coords: [b, c]),
      ]);

      expect(stitched.length, equals(1));
      expect(stitched.first.coords, equals([a, b, c]));
    });

    test('snaps a mode-change run onto the previous run end (no gap)', () {
      const walkEnd = LatLng(-1.2850, 36.8183);
      const rideStart = LatLng(-1.2851, 36.8184);
      const rideEnd = LatLng(-1.2875, 36.8200);

      final stitched = PolylineRendererService.stitchRuns([
        const PolylineSegmentRun(mode: SegmentMode.walk, coords: [
          LatLng(-1.2833, 36.8167),
          walkEnd,
        ]),
        const PolylineSegmentRun(
            mode: SegmentMode.matatu, coords: [rideStart, rideEnd]),
      ]);

      expect(stitched.length, equals(2));
      // The matatu run must begin exactly where the walk ended.
      expect(stitched[1].coords.first, equals(walkEnd));
      // Its own interior points are preserved after the snapped start.
      expect(stitched[1].coords[1], equals(rideStart));
      expect(stitched[1].coords.last, equals(rideEnd));
    });

    test('keeps an already-shared junction point without duplication', () {
      const junction = LatLng(-1.2850, 36.8183);
      final stitched = PolylineRendererService.stitchRuns([
        const PolylineSegmentRun(mode: SegmentMode.walk, coords: [
          LatLng(-1.2833, 36.8167),
          junction,
        ]),
        const PolylineSegmentRun(mode: SegmentMode.matatu, coords: [
          junction,
          LatLng(-1.2875, 36.8200),
        ]),
      ]);

      expect(stitched.length, equals(2));
      expect(stitched[0].coords.last, equals(stitched[1].coords.first));
      expect(stitched[1].coords.first, equals(junction));
    });

    test('stitches a full walk-ride-walk journey contiguously', () {
      const origin = LatLng(-1.2833, 36.8167);
      const boarding = LatLng(-1.2850, 36.8183);
      const alighting = LatLng(-1.2875, 36.8200);
      const destination = LatLng(-1.2890, 36.8220);
      final matatuPath = [
        boarding,
        const LatLng(-1.2860, 36.8190),
        alighting,
      ];

      final journey = ActiveJourney(segments: [
        RouteSegment.walk(
          label: 'Walk to Stage A',
          coordinates: [origin, boarding],
          startPoint: origin,
          endPoint: boarding,
        ),
        RouteSegment.matatu(
          label: 'Ride Route 46',
          coordinates: matatuPath,
          routeNumber: '46',
          startPoint: boarding,
          endPoint: alighting,
        ),
        RouteSegment.walk(
          label: 'Walk to destination',
          coordinates: [alighting, destination],
          startPoint: alighting,
          endPoint: destination,
        ),
      ]);

      final runs = PolylineRendererService.stitchRuns(
          PolylineRendererService.runsFromSegments(journey.segments));

      expect(runs.length, equals(3));
      expect(runs.map((r) => r.mode).toList(),
          equals([SegmentMode.walk, SegmentMode.matatu, SegmentMode.walk]));
      // Every consecutive run must share its junction point.
      for (int i = 1; i < runs.length; i++) {
        expect(runs[i - 1].coords.last, runs[i].coords.first);
      }
      // The destination is the last coordinate of the final run.
      expect(runs.last.coords.last, equals(destination));
    });

    test('ignores empty-coordinate runs', () {
      final stitched = PolylineRendererService.stitchRuns([
        const PolylineSegmentRun(mode: SegmentMode.walk, coords: []),
        const PolylineSegmentRun(mode: SegmentMode.matatu, coords: [
          LatLng(-1.2850, 36.8183),
          LatLng(-1.2875, 36.8200),
        ]),
      ]);

      expect(stitched.length, equals(1));
      expect(stitched.first.mode, equals(SegmentMode.matatu));
    });
  });

  group('round joins', () {
    test('matatu annotations use round joins', () {
      final journey = ActiveJourney(segments: [
        RouteSegment.matatu(
          label: 'Ride Route 46',
          coordinates: [
            const LatLng(-1.2850, 36.8183),
            const LatLng(-1.2875, 36.8200),
          ],
          routeNumber: '46',
          startPoint: const LatLng(-1.2850, 36.8183),
          endPoint: const LatLng(-1.2875, 36.8200),
        ),
      ]);

      // Build preview options through the public render path.
      final options = PolylineRendererService.buildPreviewOptions(journey);

      expect(options, isNotEmpty);
      for (final option in options) {
        expect(option.lineJoin, equals(LineJoin.ROUND));
      }
    });

    test('walk annotations use the same solid blue style, round joins', () {
      final journey = ActiveJourney(segments: [
        RouteSegment.walk(
          label: 'Walk to Stage A',
          coordinates: [
            const LatLng(-1.2833, 36.8167),
            const LatLng(-1.2850, 36.8183),
          ],
          startPoint: const LatLng(-1.2833, 36.8167),
          endPoint: const LatLng(-1.2850, 36.8183),
        ),
      ]);

      final options = PolylineRendererService.buildPreviewOptions(journey);

      expect(options, hasLength(1));
      for (final option in options) {
        expect(option.lineJoin, equals(LineJoin.ROUND));

        expect(option.lineColor, NaviColors.routeBlue.toARGB32());
        expect(option.lineBorderColor,
            NaviColors.routeCasingLight.toARGB32());
        expect(option.lineBorderWidth,
            PolylineRendererService.casingExtraWidth);
        expect(option.lineWidth, PolylineRendererService.walkWidth);
      }
    });
  });

  group('live remaining route', () {
    const start = LatLng(-1.2800, 36.8100);
    const user = LatLng(-1.2800, 36.8109);
    const boarding = LatLng(-1.2800, 36.8110);
    const rideMid = LatLng(-1.2820, 36.8140);
    const alighting = LatLng(-1.2840, 36.8170);
    const destination = LatLng(-1.2850, 36.8180);

    List<List<double>> coordinatesOf(PolylineAnnotationOptions option) =>
        option.geometry.coordinates
            .map((point) => [point.lng.toDouble(), point.lat.toDouble()])
            .toList();

    bool containsPoint(List<List<double>> points, LatLng point) => points.any(
          (p) =>
              (p[0] - point.longitude).abs() < 1e-9 &&
              (p[1] - point.latitude).abs() < 1e-9,
        );

    ActiveJourney journey() => ActiveJourney(
          segments: [
            RouteSegment.walk(
              label: 'Walk to Stage A',
              coordinates: [start, boarding],
              startPoint: start,
              endPoint: boarding,
            ),
            RouteSegment.matatu(
              label: 'Ride Route 69',
              coordinates: [boarding, rideMid, alighting],
              routeNumber: '69',
              startPoint: boarding,
              endPoint: alighting,
            ),
            RouteSegment.walk(
              label: 'Walk to destination',
              coordinates: [alighting, destination],
              startPoint: alighting,
              endPoint: destination,
            ),
          ],
          currentPosition: user,
        );

    test('keeps every remaining leg and trims geometry behind the user', () {
      final options = PolylineRendererService.buildLiveOptions(journey());
      final blue = options
          .where((o) => o.lineColor == NaviColors.routeBlue.toARGB32())
          .toList();

      // Walk, final walk and ride are all still drawn after the GPS fix.
      expect(blue, hasLength(3));
      expect(
        blue.map((o) => o.lineWidth).toList(),
        [
          PolylineRendererService.walkWidth,
          PolylineRendererService.walkWidth,
          PolylineRendererService.rideWidth,
        ],
      );

      final currentWalk = coordinatesOf(blue.first);
      expect(currentWalk.first, [user.longitude, user.latitude]);
      expect(currentWalk.last, [boarding.longitude, boarding.latitude]);
      expect(containsPoint(currentWalk, start), isFalse,
          reason: 'the walked segment behind the puck is not blue any more');

      final allBlue = blue.expand(coordinatesOf).toList();
      for (final point in [boarding, rideMid, alighting, destination]) {
        expect(containsPoint(allBlue, point), isTrue,
            reason: 'missing a remaining point $point');
      }
    });

    test('uses the night blue with near-black casing in dark mode', () {
      final options =
          PolylineRendererService.buildLiveOptions(journey(), isDark: true);
      final blue = options
          .where((o) => o.lineColor == NaviColors.routeBlueDark.toARGB32())
          .toList();
      expect(blue, hasLength(3));
      expect(NaviColors.routeBlueDark, const Color(0xFF4C8DF6));
      for (final option in blue) {
        expect(option.lineBorderColor,
            NaviColors.routeCasingDark.toARGB32());
        expect(option.lineBorderWidth,
            PolylineRendererService.casingExtraWidth);
      }
    });

    test('camera geometry covers roughly the next 300 m, not the whole trip',
        () {
      final ahead = PolylineRendererService.pointsAhead(journey(), meters: 300);

      expect(ahead.first, user);
      expect(
          containsPoint(ahead.map((p) => [p.longitude, p.latitude]).toList(),
              destination),
          isFalse);

      var covered = 0.0;
      for (var i = 1; i < ahead.length; i++) {
        covered += nav_distance.DistanceCalculator.distanceMeters(
          ahead[i - 1],
          ahead[i],
        );
      }
      expect(covered, greaterThan(250));
      expect(covered, lessThanOrEqualTo(301));
    });
  });
}
