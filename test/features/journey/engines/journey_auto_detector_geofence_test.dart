import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/features/journey/engines/journey_auto_detector.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';
import 'package:navi_app/models/stage_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JourneyAutoDetector geofence arrival', () {
    late JourneyAutoDetector detector;
    late StageRecord pickupStage;
    late StageRecord destinationStage;

    setUpAll(() async {
      final db = StageDatabase();
      final stages = await db.getAllStages();
      expect(stages.length, greaterThanOrEqualTo(2));
      pickupStage = stages.first;
      destinationStage = stages.last;
    });

    setUp(() {
      detector = JourneyAutoDetector();
    });

    test(
        'reaching the pickup stage geofence advances WALK_TO_PICKUP -> '
        'WAITING and fires onStageArrived', () async {
      var arrivalFired = false;
      detector.onStageArrived = () => arrivalFired = true;

      await detector.configureEngine(
        destinationLat: destinationStage.latitude,
        destinationLng: destinationStage.longitude,
        startLat: pickupStage.latitude,
        startLng: pickupStage.longitude,
        routeStopNames: [pickupStage.stageName, destinationStage.stageName],
      );

      expect(detector.detectedPhase, JourneyPhase.walkingToStage);

      // Feed a stationary sample standing exactly on the pickup stage.
      await detector.processSample(
        pickupStage.latitude,
        pickupStage.longitude,
        0,
      );

      expect(
        detector.detectedPhase,
        JourneyPhase.waitingForMatatu,
        reason: 'State 1 -> 2 must trigger on geofence arrival (spec 2)',
      );
      expect(arrivalFired, isTrue);
    });

    test('arrival at a non-pickup stage does NOT advance the FSM', () async {
      final db = StageDatabase();
      final stages = await db.getAllStages();
      // A third stage that is not the pickup target.
      final otherStage = stages.length > 2 ? stages[1] : pickupStage;

      await detector.configureEngine(
        destinationLat: destinationStage.latitude,
        destinationLng: destinationStage.longitude,
        startLat: pickupStage.latitude,
        startLng: pickupStage.longitude,
        routeStopNames: [pickupStage.stageName, destinationStage.stageName],
      );

      await detector.processSample(otherStage.latitude, otherStage.longitude, 0);

      expect(detector.detectedPhase, JourneyPhase.walkingToStage);
    });
  });
}