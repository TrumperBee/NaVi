import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/providers/journey_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'auto-detection must be aimed at the real stage coordinates: the start '
      'at the pickup stage (not the city-centre fallback) and the alight at '
      'the alight stage (not the searched destination place)', () async {
    const fromStage = LatLng(-1.2473, 36.9141);
    const toStage = LatLng(-1.2034, 37.0892);
    const destinationPlace = LatLng(-1.3012, 36.7837);

    final provider = JourneyProvider();
    provider.toggleAutoAdvance(); // avoid starting real GPS in the test

    await provider.startJourney(
      destinationName: 'Some search result place',
      destinationPoint: destinationPlace,
      fromStageName: 'Kencom',
      fromStageId: 'kencom',
      fromStageLocation: fromStage,
      toStageName: 'Githurai',
      toStageId: 'githurai',
      toStageLocation: toStage,
      routeNumber: '44',
      routeName: 'CBD - Githurai 44',
      estimatedFare: 60,
      estimatedDuration: 55,
      stopNames: const ['Kencom', 'OTC', 'Roysambu', 'Kasarani', 'Githurai'],
    );

    final coords = provider.resolveAutoDetectionCoordinates();

    expect(coords.startLat, fromStage.latitude,
        reason: 'deviation/wrong-direction baseline must be the pickup stage,'
            ' not the -1.2833/36.8167 city-centre constant');
    expect(coords.startLng, fromStage.longitude);
    expect(coords.destLat, toStage.latitude,
        reason: 'the alight engine must aim at the alight STAGE, not the '
            'destination place (transit ends at the stage, walking finishes '
            'the last leg)');
    expect(coords.destLng, toStage.longitude);
    expect(coords.destLat, isNot(destinationPlace.latitude));
    expect(coords.destLng, isNot(destinationPlace.longitude));
  });
}