import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navi_app/features/map/route_marker_style.dart';

void main() {
  group('RouteMarkerStyle', () {
    test('departure is an emerald disc with a white ring', () {
      expect(RouteMarkerStyle.departureShape, RouteMarkerShape.circle);
      expect(RouteMarkerStyle.departureFill, const Color(0xFF00875A));
      expect(RouteMarkerStyle.departureRing, Colors.white);
      expect(RouteMarkerStyle.departureRingWidth, greaterThan(0));
    });

    test('destination is a red-outlined pin, distinct from departure', () {
      expect(RouteMarkerStyle.destinationShape, RouteMarkerShape.pin);
      expect(RouteMarkerStyle.destinationOutline, const Color(0xFFC62828));
      expect(RouteMarkerStyle.destinationFill, Colors.white);
      expect(
        RouteMarkerStyle.destinationOutline,
        isNot(RouteMarkerStyle.departureFill),
      );
      expect(
        RouteMarkerStyle.destinationShape,
        isNot(RouteMarkerStyle.departureShape),
      );
    });

    test('GPS puck is signal blue with a translucent accuracy ring', () {
      expect(RouteMarkerStyle.gpsPuck, const Color(0xFF1A73E8));
      expect(RouteMarkerStyle.gpsPuck, isNot(RouteMarkerStyle.departureFill));
      expect(RouteMarkerStyle.gpsPuck, isNot(RouteMarkerStyle.destinationOutline));
      expect(RouteMarkerStyle.gpsAccuracyFillOpacity, greaterThan(0));
      expect(RouteMarkerStyle.gpsAccuracyFillOpacity, lessThan(1));
    });
  });
}
