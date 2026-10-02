import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/features/journey/engines/journey_auto_detector.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';
import 'package:navi_app/models/stage_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JourneyAutoDetector State 1 must not stall', () {
    late JourneyAutoDetector detector;
    late StageRecord pickupStage;
    late StageRecord destinationStage;

    setUpAll(() async {
      final db = StageDatabase();
      final kencom = await db.searchStages('Kencom');
      final githurai = await db.searchStages('Githurai');
      pickupStage = kencom.first;
      destinationStage = githurai.first;
    });

    setUp(() {
      detector = JourneyAutoDetector();
    });

    test(
        'when tracking starts with the user already riding at speed, the FSM '
        'must leave walkingToStage and advance to riding even though the '
        'pickup geofence is never entered (State-1 stall regression guard)',
        () async {
      await detector.configureEngine(
        destinationLat: destinationStage.latitude,
        destinationLng: destinationStage.longitude,
        startLat: pickupStage.latitude,
        startLng: pickupStage.longitude,
        routeStopNames: [pickupStage.stageName, destinationStage.stageName],
      );
      // No initial walking samples, and every GPS point stays away from the
      // pickup stage geofence; the FSM must not stall in walkingToStage.
      for (var i = 0; i < 8; i++) {
        await detector.processSample(
            destinationStage.latitude, destinationStage.longitude, 14.0);
      }

      expect(
        detector.detectedPhase,
        isNot(JourneyPhase.walkingToStage),
        reason: 'sustained inVehicle speed must induct State 1 -> 3 instead of '
            'stalling in walkingToStage forever',
      );
    });
  });
}