import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/features/journey/engines/journey_auto_detector.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';
import 'package:navi_app/models/stage_record.dart';
import 'package:navi_app/utils/geo_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JourneyAutoDetector alighting (movement-state fallback)', () {
    late JourneyAutoDetector detector;
    late StageRecord pickupStage;
    late StageRecord destinationStage;

    setUpAll(() async {
      final db = StageDatabase();
      final stages = await db.getAllStages();
      // Pick the pickup as the first stage and the destination as the stage
      // FARTHEST from it, so geo-based alighting cannot engage while the
      // simulated rider never approaches it.
      final first = stages.first;
      StageRecord farthest = first;
      var best = 0.0;
      final resting = stages.skip(1);
      for (final s in resting) {
        final d = haversineDistance(
          first.latitude, first.longitude,
          s.latitude, s.longitude,
        );
        if (d > best) {
          best = d;
          farthest = s;
        }
      }
      pickupStage = first;
      destinationStage = farthest;
      expect(best, greaterThan(2000),
          reason: 'stages must be >2km apart so geo approach cannot trigger');
    });

    setUp(() {
      detector = JourneyAutoDetector();
    });

    test(
        'getting out of a matatu is detected even when the geo engine cannot '
        'confirm alighting (boarding engine didAlight must be live)', () async {
      var alighted = false;
      detector.onAlighted = () => alighted = true;

      await detector.configureEngine(
        destinationLat: destinationStage.latitude,
        destinationLng: destinationStage.longitude,
        startLat: pickupStage.latitude,
        startLng: pickupStage.longitude,
        routeStopNames: [pickupStage.stageName, destinationStage.stageName],
      );

      // 1) Arrive at the pickup stage geofence -> State 1 -> 2.
      await detector.processSample(pickupStage.latitude, pickupStage.longitude, 0);
      expect(detector.detectedPhase, JourneyPhase.waitingForMatatu);

      // 2) Board and ride, all coordinates far (>2km) from the destination so
      //    the geo alight engine can never satisfy distance<500m.
      for (var i = 0; i < 6; i++) {
        await detector.processSample(pickupStage.latitude, pickupStage.longitude, 14.0);
      }
      expect(detector.detectedPhase, JourneyPhase.riding,
          reason: 'sustained vehicle speed must move State 2 -> 3');

      for (var i = 0; i < 8; i++) {
        await detector.processSample(pickupStage.latitude, pickupStage.longitude, 14.0);
      }
      expect(detector.detectedPhase, JourneyPhase.riding);

      // 3) The rider gets off: sustained walking speed. With the geo engine
      //    unusable (far from destination), the movement-state alight signal
      //    must still carry the FSM to WALK_TO_FINAL_DESTINATION.
      for (var i = 0; i < 22; i++) {
        await detector.processSample(pickupStage.latitude, pickupStage.longitude, 1.0);
      }

      expect(
        detector.detectedPhase,
        JourneyPhase.alighting,
        reason: 'boarding.didAlight must act as the alighting fallback when '
            'the geo engine cannot confirm',
      );
      expect(alighted, isTrue);
    });
  });
}