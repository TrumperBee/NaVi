import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/data/databases/stage_database.dart';
import 'package:navi_app/features/journey/engines/journey_auto_detector.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';
import 'package:navi_app/models/stage_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JourneyAutoDetector route matching during a journey', () {
    late JourneyAutoDetector detector;
    late List<StageRecord> route44Stages;

    setUpAll(() async {
      final db = StageDatabase();
      const names = ['Kencom', 'OTC', 'Roysambu', 'Kasarani', 'Githurai'];
      route44Stages = [];
      for (final name in names) {
        final res = await db.searchStages(name);
        expect(res, isNotEmpty, reason: '$name must resolve');
        route44Stages.add(res.first);
      }
    });

    setUp(() {
      detector = JourneyAutoDetector();
    });

    test(
        'riding the expected route exposes a live route match '
        '(routeConfidence must come from RouteMatcherEngine, not stay 0)', () async {
      final pickup = route44Stages.first;
      final destination = route44Stages.last;

      await detector.configureEngine(
        destinationLat: destination.latitude,
        destinationLng: destination.longitude,
        startLat: pickup.latitude,
        startLng: pickup.longitude,
        routeStopNames: route44Stages.map((s) => s.stageName).toList(),
        routeNumber: '44',
      );

      // Arrive at the pickup stage -> State 1 -> 2.
      await detector.processSample(pickup.latitude, pickup.longitude, 0);
      expect(detector.detectedPhase, JourneyPhase.waitingForMatatu);

      // Ride from Kencom up to Kasarani (still well outside the 500 m
      // approach radius of the Githurai destination) along the real coords.
      final riddenStages = route44Stages.take(4).toList();
      for (var pass = 0; pass < 2; pass++) {
        for (final stage in riddenStages) {
          await detector.processSample(stage.latitude, stage.longitude, 14.0);
        }
      }
      expect(detector.detectedPhase, JourneyPhase.riding);

      // Let the (async) route matcher settle.
      for (var i = 0; i < 10; i++) {
        await pumpEventQueue();
      }

      expect(
        detector.routeConfidence,
        greaterThan(0),
        reason: 'the route matcher must actually run during the journey '
            'instead of routeConfidence staying 0 forever',
      );
      expect(detector.currentMatch, isNotNull);
      expect(detector.currentMatch!.isOnRoute, isTrue);
    });
  });
}