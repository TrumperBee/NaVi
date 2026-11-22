import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:navi_app/services/gps_jitter_filter.dart';

const _origin = LatLng(-1.2833, 36.8167);
const _metersPerLatitudeDegree = 111194.92664455873;

LatLng _north(LatLng point, double meters) => LatLng(
      point.latitude + meters / _metersPerLatitudeDegree,
      point.longitude,
    );

void main() {
  group('GpsJitterFilter', () {
    test('accepts the first fix', () {
      final filter = GpsJitterFilter();

      expect(filter.shouldAccept(_origin), isTrue);
      expect(filter.lastAccepted, _origin);
    });

    test('ignores fixes under 5 m and keeps the last accepted point', () {
      final filter = GpsJitterFilter()..seed(_origin);
      final jitter = _north(_origin, 4.9);

      expect(filter.shouldAccept(jitter), isFalse);
      expect(filter.lastAccepted, _origin);

      // A second small move must be measured from the original accepted fix,
      // not from the jitter that was ignored.
      expect(filter.shouldAccept(_north(_origin, 1.0)), isFalse);
    });

    test('accepts a move of at least 5 m', () {
      final filter = GpsJitterFilter()..seed(_origin);
      final moved = _north(_origin, 5.1);

      expect(filter.shouldAccept(moved), isTrue);
      expect(filter.lastAccepted!.latitude, closeTo(moved.latitude, 1e-10));
    });

    test('reset lets the same coordinate be accepted again', () {
      final filter = GpsJitterFilter()
        ..seed(_origin)
        ..reset();

      expect(filter.shouldAccept(_north(_origin, 1.0)), isTrue);
    });
  });
}
