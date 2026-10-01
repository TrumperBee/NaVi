import 'package:test/test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/services/proximity_alert_service.dart';
import 'package:navi_app/models/proximity_threshold.dart';

void main() {
  group('ProximityAlertService', () {
    late ProximityAlertService service;

    setUp(() {
      service = ProximityAlertService();
    });

    tearDown(() {
      service.dispose();
    });

    group('resetForNewTarget', () {
      test('resets thresholds and sets new target', () {
        final target = ProximityTarget.fromStage('Test Stage', -1.2833, 36.8167);
        service.resetForNewTarget(target);

        expect(service.currentTarget, equals(target));
        expect(service.currentTarget!.label, equals('Test Stage'));
      });

      test('resets hasFired flags on target change', () async {
        final target1 = ProximityTarget.fromStage('Stage A', -1.2833, 36.8167);
        final target2 = ProximityTarget.fromStage('Stage B', -1.2900, 36.8200);

        service.resetForNewTarget(target1);

        final events = <ProximityAlertEvent>[];
        final subscription = service.events.listen(events.add);

        // Fire 1km threshold
        service.checkProximity(const LatLng(-1.2763, 36.8167)); // ~780m from target1
        await Future.delayed(const Duration(milliseconds: 10));
        expect(events.length, equals(1));

        // Change target
        service.resetForNewTarget(target2);

        // Thresholds should be reset, so 1km should fire again
        service.checkProximity(const LatLng(-1.2837, 36.8200)); // ~700m from target2
        await Future.delayed(const Duration(milliseconds: 10));
        expect(events.length, equals(2));
        expect(events[1].threshold, equals(ProximityDistance.oneKm));

        await subscription.cancel();
      });
    });

    group('checkProximity - progressive approach', () {
      test('fires thresholds in order: 1km, 500m, 100m, 50m', () async {
        final target = ProximityTarget.fromStage('Test Stage', -1.2833, 36.8167);
        service.resetForNewTarget(target);

        final events = <ProximityAlertEvent>[];
        final subscription = service.events.listen(events.add);

        // Start at ~1200m (no fire)
        service.checkProximity(LatLng(-1.2720, 36.8167));
        await Future.delayed(const Duration(milliseconds: 10));
        expect(events.length, equals(0));

        // Move to ~670m (1km fires)
        service.checkProximity(LatLng(-1.2773, 36.8167));
        await Future.delayed(const Duration(milliseconds: 10));
        expect(events.length, equals(1));
        expect(events[0].threshold, equals(ProximityDistance.oneKm));

        // Move to ~400m (500m fires)
        service.checkProximity(LatLng(-1.2793, 36.8167));
        await Future.delayed(const Duration(milliseconds: 10));
        expect(events.length, equals(2));
        expect(events[1].threshold, equals(ProximityDistance.fiveHundredM));

        // Move to ~80m (100m fires)
        service.checkProximity(LatLng(-1.2825, 36.8167));
        await Future.delayed(const Duration(milliseconds: 10));
        expect(events.length, equals(3));
        expect(events[2].threshold, equals(ProximityDistance.oneHundredM));

        // Move to ~30m (50m fires)
        service.checkProximity(LatLng(-1.2830, 36.8167));
        await Future.delayed(const Duration(milliseconds: 10));
        expect(events.length, equals(4));
        expect(events[3].threshold, equals(ProximityDistance.fiftyM));

        await subscription.cancel();
      });

      test('each threshold fires exactly once per target', () async {
        final target = ProximityTarget.fromStage('Test Stage', -1.2833, 36.8167);
        service.resetForNewTarget(target);

        final events = <ProximityAlertEvent>[];
        final subscription = service.events.listen(events.add);

        // Approach target
        service.checkProximity(LatLng(-1.2773, 36.8167)); // ~670m
        await Future.delayed(const Duration(milliseconds: 10));
        service.checkProximity(LatLng(-1.2793, 36.8167)); // ~400m
        await Future.delayed(const Duration(milliseconds: 10));
        service.checkProximity(LatLng(-1.2825, 36.8167)); // ~80m
        await Future.delayed(const Duration(milliseconds: 10));
        service.checkProximity(LatLng(-1.2830, 36.8167)); // ~30m
        await Future.delayed(const Duration(milliseconds: 10));

        // Move around near target - should not fire again
        service.checkProximity(LatLng(-1.2831, 36.8167));
        await Future.delayed(const Duration(milliseconds: 10));
        service.checkProximity(LatLng(-1.2832, 36.8167));
        await Future.delayed(const Duration(milliseconds: 10));

        expect(events.length, equals(4)); // 1km, 500m, 100m, 50m only

        await subscription.cancel();
      });
    });

    group('GPS jump handling', () {
      test('jump from 1200m to 80m fires 1km, 500m, 100m (closest displayed)', () async {
        final target = ProximityTarget.fromStage('Test Stage', -1.2833, 36.8167);
        service.resetForNewTarget(target);

        final events = <ProximityAlertEvent>[];
        final subscription = service.events.listen(events.add);

        // Start at 1200m (no fire)
        service.checkProximity(LatLng(-1.2720, 36.8167));
        await Future.delayed(const Duration(milliseconds: 10));

        // GPS jumps to 80m (should fire 1km, 500m, 100m internally but only 100m displayed)
        service.checkProximity(LatLng(-1.2825, 36.8167));
        await Future.delayed(const Duration(milliseconds: 10));

        // Should get one event for the closest crossed threshold (100m)
        expect(events.length, equals(1));
        expect(events[0].threshold, equals(ProximityDistance.oneHundredM));

        // 50m should not have fired yet
        expect(events.any((e) => e.threshold == ProximityDistance.fiftyM), isFalse);

        await subscription.cancel();
      });
    });

    group('final destination arrival', () {
      test('50m on final destination emits arrivalConfirmed', () async {
        final target = ProximityTarget.fromStage('Final Destination', -1.2833, 36.8167, isFinal: true);
        service.resetForNewTarget(target);

        final events = <ProximityAlertEvent>[];
        final subscription = service.events.listen(events.add);

        // Approach final destination
        service.checkProximity(LatLng(-1.2743, 36.8167)); // ~900m
        await Future.delayed(const Duration(milliseconds: 10));
        service.checkProximity(LatLng(-1.2793, 36.8167)); // ~400m
        await Future.delayed(const Duration(milliseconds: 10));
        service.checkProximity(LatLng(-1.2825, 36.8167)); // ~80m
        await Future.delayed(const Duration(milliseconds: 10));
        service.checkProximity(LatLng(-1.2830, 36.8167)); // ~30m
        await Future.delayed(const Duration(milliseconds: 10));

        expect(events.length, equals(3));
        expect(events[2].type, equals(ProximityAlertType.arrivalConfirmed));
        expect(events[2].threshold, equals(ProximityDistance.fiftyM));

        await subscription.cancel();
      });
    });

    group('alerts disabled', () {
      test('no events fired when alerts disabled', () async {
        final target = ProximityTarget.fromStage('Test Stage', -1.2833, 36.8167);
        service.resetForNewTarget(target);
        service.alertsEnabled = false;

        final events = <ProximityAlertEvent>[];
        final subscription = service.events.listen(events.add);

        service.checkProximity(LatLng(-1.2830, 36.8167));
        await Future.delayed(const Duration(milliseconds: 10));

        expect(events.length, equals(0));

        await subscription.cancel();
      });
    });

    group('distance calculations', () {
      test('~550m gap fires 1km threshold but not 500m', () async {
        final target = ProximityTarget.fromStage('Railways', -1.2875, 36.8200);
        service.resetForNewTarget(target);

        final events = <ProximityAlertEvent>[];
        final subscription = service.events.listen(events.add);

        // Kencom -> Railways is ~550m apart
        service.checkProximity(const LatLng(-1.2833, 36.8167));
        await Future.delayed(const Duration(milliseconds: 10));

        expect(events.length, equals(1));
        expect(events[0].threshold, equals(ProximityDistance.oneKm));

        await subscription.cancel();
      });

      test('distance is order-agnostic (symmetric)', () async {
        // Approach from the far side of the target at ~550m and verify the
        // same threshold fires regardless of heading.
        final target = ProximityTarget.fromStage('Railways', -1.2875, 36.8200);
        service.resetForNewTarget(target);

        final events = <ProximityAlertEvent>[];
        final subscription = service.events.listen(events.add);

        service.checkProximity(const LatLng(-1.2875, 36.8145)); // west side, ~550m
        await Future.delayed(const Duration(milliseconds: 10));

        expect(events.length, equals(1));
        expect(events[0].threshold, equals(ProximityDistance.oneKm));

        await subscription.cancel();
      });
    });
  });
}