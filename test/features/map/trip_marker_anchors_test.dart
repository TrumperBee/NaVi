import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:navi_app/features/map/trip_marker_anchors.dart';

void main() {
  group('TripMarkerAnchors', () {
    const plannedOrigin = LatLng(-1.2801, 36.8102);
    const gpsDrift = LatLng(-1.2815, 36.8140);

    test('stores the planned departure only once', () {
      final anchors = TripMarkerAnchors();

      expect(anchors.confirmDeparture(plannedOrigin), isTrue);
      expect(anchors.departure, plannedOrigin);

      // Simulates every later GPS fix: the stored anchor must not move.
      expect(anchors.confirmDeparture(gpsDrift), isFalse);
      expect(anchors.departure, plannedOrigin);
    });

    test('marker key is unaffected by later coordinate writes', () {
      final anchors = TripMarkerAnchors()..confirmDeparture(plannedOrigin);
      final key = anchors.key;

      anchors.confirmDeparture(gpsDrift);

      expect(anchors.key, key);
    });

    test('clear allows the next journey to store a fresh departure', () {
      final anchors = TripMarkerAnchors()..confirmDeparture(plannedOrigin);

      expect(anchors.clear(), isTrue);
      expect(anchors.departure, isNull);
      expect(anchors.clear(), isFalse);
      expect(anchors.confirmDeparture(gpsDrift), isTrue);
      expect(anchors.departure, gpsDrift);
    });
  });
}
