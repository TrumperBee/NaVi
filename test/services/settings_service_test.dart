import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navi_app/models/app_settings.dart';
import 'package:navi_app/models/journey_record.dart';
import 'package:navi_app/services/settings_service.dart';
import 'package:navi_app/utils/distance_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads defaults when nothing is persisted', () async {
      final service = SettingsService();
      await service.load();
      expect(service.isDarkTheme, false);
      expect(service.notificationsEnabled, true);
      expect(service.voiceGuidanceEnabled, true);
      expect(service.distanceUnit, DistanceUnit.km);
      expect(service.locationSharingEnabled, true);
      expect(service.completedJourneys, 0);
      expect(service.totalKmTraveled, 0);
    });

    test('restores persisted values on load', () async {
      SharedPreferences.setMockInitialValues({
        'navi.settings.dark_mode': true,
        'navi.settings.notifications_enabled': false,
        'navi.settings.distance_unit': 'mi',
        'navi.settings.high_accuracy_mode': false,
        'navi.settings.completed_journeys': 4,
      });
      final service = SettingsService();
      await service.load();
      expect(service.isDarkTheme, true);
      expect(service.notificationsEnabled, false);
      expect(service.distanceUnit, DistanceUnit.mi);
      expect(service.highAccuracyMode, false);
      expect(service.completedJourneys, 4);
      expect(DistanceFormatter.currentUnit, DistanceUnit.mi);
    });

    test('toggleTheme persists and notifies', () async {
      final service = SettingsService();
      await service.load();
      var notified = false;
      service.addListener(() => notified = true);
      service.toggleTheme();
      expect(service.isDarkTheme, true);
      expect(notified, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('navi.settings.dark_mode'), true);
    });

    test('setDistanceUnit persists and syncs DistanceFormatter', () async {
      final service = SettingsService();
      await service.load();
      service.setDistanceUnit(DistanceUnit.mi);
      expect(service.distanceUnit, DistanceUnit.mi);
      expect(DistanceFormatter.currentUnit, DistanceUnit.mi);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('navi.settings.distance_unit'), 'mi');
    });

    test('setNotificationsEnabled gates proximity alerts', () async {
      final service = SettingsService();
      await service.load();
      service.setNotificationsEnabled(false);
      expect(service.notificationsEnabled, false);
      expect(
        service.settings.notificationsEnabled,
        false,
      );
    });

    test('setHighAccuracyMode toggles', () async {
      final service = SettingsService();
      await service.load();
      service.toggleHighAccuracyMode();
      expect(service.highAccuracyMode, false);
    });

    test('recordJourneyCompletion accumulates stats', () async {
      final service = SettingsService();
      await service.load();
      service.recordJourneyCompletion(12.5);
      service.recordJourneyCompletion(7.2);
      expect(service.completedJourneys, 2);
      expect(service.totalKmTraveled, closeTo(19.7, 0.001));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('navi.settings.completed_journeys'), 2);
      expect(prefs.getDouble('navi.settings.total_km_traveled'),
          closeTo(19.7, 0.001));
    });

    test('incrementReportsSubmitted accumulates', () async {
      final service = SettingsService();
      await service.load();
      service.incrementReportsSubmitted();
      service.incrementReportsSubmitted();
      expect(service.reportsSubmitted, 2);
    });

    test('clearJourneyHistory resets stats', () async {
      final service = SettingsService();
      await service.load();
      service.recordJourneyCompletion(12.5);
      service.incrementContributions();
      await service.clearJourneyHistory();
      expect(service.completedJourneys, 0);
      expect(service.totalKmTraveled, 0);
      expect(service.totalContributions, 0);
      expect(service.reportsSubmitted, 0);
      expect(service.journeyRecords, isEmpty);
    });

    JourneyRecord record({
      double km = 8.4,
      List<String> stages = const ['Kencom Bus Station'],
    }) {
      return JourneyRecord(
        date: DateTime(2026, 9, 26),
        originLabel: 'Mulhongo Close',
        destinationLabel: 'Githurai 45 Stage',
        distanceKm: km,
        fareKsh: 120,
        durationMinutes: 45,
        stageNames: stages,
      );
    }

    test('addJourneyRecord inserts newest first and keeps counters in sync',
        () async {
      final service = SettingsService();
      await service.load();
      service.addJourneyRecord(record(km: 12.5, stages: ['Stage A']));
      service.addJourneyRecord(record(km: 7.2, stages: ['Stage B']));

      expect(service.journeyRecords.length, 2);
      // Newest first.
      expect(service.journeyRecords.first.distanceKm, closeTo(7.2, 0.001));
      expect(service.distinctStages, 2);
      // addJourneyRecord also feeds the legacy counters.
      expect(service.completedJourneys, 2);
      expect(service.totalKmTraveled, closeTo(19.7, 0.001));

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('navi.settings.journey_records');
      expect(stored, isNotNull);
      expect(stored!.length, 2);
    });

    test('distinctStages counts unique alighting stages across trips', () async {
      final service = SettingsService();
      await service.load();
      service.addJourneyRecord(record(stages: ['Kencom Bus Station']));
      service.addJourneyRecord(record(stages: ['Kencom Bus Station']));
      service.addJourneyRecord(
          record(stages: ['Githurai 45 Stage', 'Roysambu Stage']));

      expect(service.distinctStages, 3);
    });

    test('journey records survive a fresh load from persisted storage', () async {
      final service = SettingsService();
      await service.load();
      service.addJourneyRecord(record(km: 5.5));

      final fresh = SettingsService();
      await fresh.load();
      expect(fresh.journeyRecords.length, 1);
      expect(fresh.journeyRecords.first.distanceKm, closeTo(5.5, 0.001));
      expect(fresh.journeyRecords.first.originLabel, 'Mulhongo Close');
      expect(fresh.distinctStages, 1);
    });

    test('corrupt persisted records are skipped without breaking load', () async {
      final prefs = await SharedPreferences.getInstance();
      prefs.setStringList('navi.settings.journey_records', [
        'garbage-entry',
        record().toJson(),
      ]);

      final service = SettingsService();
      await service.load();
      expect(service.journeyRecords.length, 1);
      expect(service.journeyRecords.first.destinationLabel, 'Githurai 45 Stage');
    });

    test('clearJourneyHistory also clears persisted journey records', () async {
      final service = SettingsService();
      await service.load();
      service.addJourneyRecord(record());
      await service.clearJourneyHistory();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('navi.settings.journey_records'), isNull);
    });

    test('grouped settings snapshot reflects current state', () async {
      final service = SettingsService();
      await service.load();
      service.setTheme(true);
      expect(service.settings.darkMode, true);
      expect(service.settings.mapStyle, MapStyle.night);
    });

    group('saved places', () {
      test('savedPlace is null before any place is set', () async {
        final service = SettingsService();
        await service.load();
        expect(service.savedPlace(SavedPlaceKind.home), isNull);
        expect(service.savedPlace(SavedPlaceKind.work), isNull);
        expect(service.savedPlace(SavedPlaceKind.campus), isNull);
      });

      test('setSavedPlace persists JSON and survives a fresh load', () async {
        final service = SettingsService();
        await service.load();
        service.setSavedPlace(
          SavedPlaceKind.home,
          const SavedPlace(lat: -1.286, lng: 36.817, label: 'My House'),
        );

        final fresh = SettingsService();
        await fresh.load();
        final home = fresh.savedPlace(SavedPlaceKind.home);
        expect(home, isNotNull);
        expect(home!.label, 'My House');
        expect(home.lat, closeTo(-1.286, 0.0001));
        expect(home.lng, closeTo(36.817, 0.0001));
      });

      test('home / work / campus are independent slots', () async {
        final service = SettingsService();
        await service.load();
        service.setSavedPlace(
            SavedPlaceKind.work,
            const SavedPlace(lat: -1.30, lng: 36.75, label: 'Office'));
        expect(service.savedPlace(SavedPlaceKind.work)!.label, 'Office');
        expect(service.savedPlace(SavedPlaceKind.home), isNull);
        expect(service.savedPlace(SavedPlaceKind.campus), isNull);
      });

      test('loads home place from persisted JSON key', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        prefs.setString(
          'navi.places.home',
          '{"lat":-1.29,"lng":36.82,"label":"Nairobi CBD"}',
        );
        final reloaded = SettingsService();
        await reloaded.load();
        final home = reloaded.savedPlace(SavedPlaceKind.home);
        expect(home, isNotNull);
        expect(home!.label, 'Nairobi CBD');
        expect(home.lat, closeTo(-1.29, 0.0001));
      });
    });
  });
}