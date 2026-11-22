import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:navi_app/design/navi_colors.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/widgets/route_preview/route_preview_polyline.dart';

const _origin = LatLng(-1.2800, 36.8100);
const _boarding = LatLng(-1.2833, 36.8167);
const _alight = LatLng(-1.2900, 36.8300);

RouteSegment _walk() => RouteSegment.walk(
      label: 'Walk',
      coordinates: const [_origin, _boarding],
      startPoint: _origin,
      endPoint: _boarding,
    );

RouteSegment _ride() => RouteSegment.matatu(
      label: 'Ride',
      coordinates: const [_boarding, _alight],
      routeNumber: '34',
      startPoint: _boarding,
      endPoint: _alight,
    );

void main() {
  test('no line until real segments exist', () {
    expect(
      RoutePreviewPolyline.build(ActiveJourney(segments: const [])),
      isEmpty,
    );
  });

  test('ride is one solid 7dp blue stroke with a white 4dp casing in light mode', () {
    final options = RoutePreviewPolyline.build(
      ActiveJourney(segments: [_ride()]),
    );
    expect(options, hasLength(1));
    final ride = options.single;
    expect(ride.lineColor, NaviColors.routeBlue.toARGB32());
    expect(NaviColors.routeBlue, const Color(0xFF1A73E8));
    expect(ride.lineWidth, 7.0);
    expect(ride.lineBorderColor, NaviColors.routeCasingLight.toARGB32());
    expect(NaviColors.routeCasingLight, const Color(0xFFFFFFFF));
    expect(ride.lineBorderWidth, 4.0);
    expect(ride.lineJoin, LineJoin.ROUND);

  });

  test('walk legs are one solid 6dp stroke, never a stitched dash line', () {
    final options = RoutePreviewPolyline.build(
      ActiveJourney(segments: [_walk(), _ride()]),
    );
    // One annotation per mode run: no dash stitching.
    expect(options, hasLength(2));
    final walk = options.firstWhere((o) => o.lineWidth == 6.0);
    expect(walk.lineColor, NaviColors.routeBlue.toARGB32());
    expect(walk.lineWidth, lessThan(7.0));
    expect(walk.lineBorderColor, NaviColors.routeCasingLight.toARGB32());
    expect(walk.lineBorderWidth, 4.0);

  });

  test('dark mode uses the night blue with a near-black casing', () {
    final options = RoutePreviewPolyline.build(
      ActiveJourney(segments: [_ride()]),
      isDark: true,
    );
    expect(options.single.lineColor, NaviColors.routeBlueDark.toARGB32());
    expect(NaviColors.routeBlueDark, const Color(0xFF4C8DF6));
    expect(options.single.lineBorderColor,
        NaviColors.routeCasingDark.toARGB32());
    expect(NaviColors.routeCasingDark, const Color(0xFF12161C));
    expect(options.single.lineBorderWidth, 4.0);
  });

  test('walk geometry is passed through without simplification', () {
    final dense = <LatLng>[
      for (var i = 0; i <= 20; i++)
        LatLng(-1.2833 + i * 0.00002, 36.8167 + i * 0.00002),
    ];
    final options = RoutePreviewPolyline.build(
      ActiveJourney(segments: [
        RouteSegment.walk(
          label: 'Walk',
          coordinates: dense,
          startPoint: dense.first,
          endPoint: dense.last,
        ),
      ]),
    );
    final coords = options.single.geometry.coordinates;
    expect(coords.length, dense.length,
        reason: 'no point closer than 5 m may be dropped');
  });
}
