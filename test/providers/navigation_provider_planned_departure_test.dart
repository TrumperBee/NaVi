import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:navi_app/providers/navigation_provider.dart';

void main() {
  test('planned departure survives GPS-like updates until navigation clears', () {
    final provider = NavigationProvider();
    addTearDown(provider.dispose);

    const planned = LatLng(-1.2800, 36.8100);
    const drifted = LatLng(-1.2900, 36.8300);

    expect(provider.plannedDeparture, isNull);
    provider.confirmPlannedDeparture(planned);
    provider.confirmPlannedDeparture(drifted);

    expect(provider.plannedDeparture, planned);

    provider.clearNavigation();
    expect(provider.plannedDeparture, isNull);
  });
}
