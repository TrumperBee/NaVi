import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/features/journey/engines/stage_geofence_engine.dart';
import 'package:navi_app/models/stage_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StageGeofenceEngine', () {
    late StageGeofenceEngine engine;
    late StageRecord pickupStage;

    setUpAll(() async {
      engine = StageGeofenceEngine();
      final db = StageDatabase();
      final stages = await db.getAllStages();
      expect(stages, isNotEmpty, reason: 'bundled stage universe loaded');
      pickupStage = stages.first;
    });

    test(
        'isAtStageName reports arrival once the user enters a stage geofence '
        '(events must be actionable, not discarded)', () async {
      // Standing physically on the pickup stage is the strongest possible
      // arrival signal: State 1 (WALK_TO_PICKUP) -> State 2 (WAITING) in the
      // spec's FSM is keyed off a ~40 m arrival geofence. If the engine cannot
      // report which stage the user is at, that transition can never happen.
      final events = await engine.checkGeofences(
        pickupStage.latitude,
        pickupStage.longitude,
      );

      expect(events, isNotEmpty);
      expect(
        events.where((e) => e.event == GeofenceEvent.entered),
        isNotEmpty,
        reason: 'on-stage sample must produce an entered event',
      );
      expect(
        engine.isAtStageName(pickupStage.stageName),
        isTrue,
        reason: 'arrival at a stage must be queryable by name so the FSM can act on it',
      );
      expect(engine.getCurrentStageName(), equals(pickupStage.stageName));
    });
  });
}