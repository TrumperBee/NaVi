import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/route_segment.dart';
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
        const PolylineSegmentRun(mode: SegmentMode.matatu, coords: [rideStart, rideEnd]),
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

    test('walk dashed annotations use round joins', () {
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

      expect(options, isNotEmpty);
      for (final option in options) {
        expect(option.lineJoin, equals(LineJoin.ROUND));
        expect(option.lineColor, const Color(0xFF00875A).toARGB32());
      }
    });
  });
}