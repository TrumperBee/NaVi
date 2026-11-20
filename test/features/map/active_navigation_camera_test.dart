import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:navi_app/features/map/mapbox_map_manager.dart';
import 'package:test/test.dart';

void main() {
  group('active navigation camera', () {
    test('bottom-heavy inset leaves the route ahead in the upper viewport', () {
      final padding = MapboxMapManager.navigationPadding(
        Size(width: 412, height: 915),
      );

      expect(padding.bottom, 915 * 0.58);
      expect(padding.top, 915 * 0.10);
      expect(padding.left, 40);
      expect(padding.right, 40);
    });

    test('matatu legs zoom out slightly while the bearing stays north-up', () {
      final rideZoom = MapboxMapManager.navigationZoom(riding: true);
      final walkZoom = MapboxMapManager.navigationZoom(riding: false);
      expect(rideZoom, lessThan(walkZoom));
      expect(rideZoom, MapboxMapManager.navigationRideZoom);
      expect(walkZoom, MapboxMapManager.navigationWalkZoom);

      final CameraOptions options =
          MapboxMapManager.navigationBaseCameraOptions();
      expect(options.bearing, 0);
      expect(options.pitch, 0);
    });
  });
}
