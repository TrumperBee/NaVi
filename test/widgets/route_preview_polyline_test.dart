import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
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

  test('ride is solid emerald 6dp with a white 2dp casing', () {
    final options = RoutePreviewPolyline.build(
      ActiveJourney(segments: [_ride()]),
    );
    expect(options, hasLength(1));
    final ride = options.single;
    expect(ride.lineColor, NaviColors.transitGreen.toARGB32());
    expect(ride.lineWidth, 6.0);
    expect(ride.lineBorderColor, 0xFFFFFFFF);
    expect(ride.lineBorderWidth, 2.0);
  });

  test('walk legs are dashed emerald 4dp strokes', () {
    final options = RoutePreviewPolyline.build(
      ActiveJourney(segments: [_walk(), _ride()]),
    );
    final dashes = options.where((o) => o.lineWidth == 4.0).toList();
    expect(dashes.length, greaterThan(1));
    for (final dash in dashes) {
      expect(dash.lineColor, NaviColors.transitGreen.toARGB32());
    }
  });
}
