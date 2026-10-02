import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/models/wait_report_model.dart';
import 'package:navi_app/data/seed_data.dart';
import 'package:navi_app/core/constants.dart';

void main() {
  group('Models', () {
    test('StageModel creates from map correctly', () {
      final map = {
        'id': 'test_stage',
        'name': 'Test Stage',
        'lat': -1.2833,
        'lng': 36.8167,
        'corridor': 'CBD',
        'routes': ['44', '45'],
        'saccos': ['Super Metro'],
        'area': 'Nairobi CBD',
      };

      final stage = StageModel.fromMap(map, 'test_stage');
      expect(stage.id, equals('test_stage'));
      expect(stage.name, equals('Test Stage'));
      expect(stage.corridor, equals('CBD'));
      expect(stage.routes, contains('44'));
    });

    test('RouteModel creates from map correctly', () {
      final map = {
        'id': 'route_44',
        'number': '44',
        'name': 'CBD - Githurai',
        'corridor': 'Thika Road',
        'majorStops': ['Kencom', 'Githurai'],
        'sacco': 'Super Metro',
      };

      final route = RouteModel.fromMap(map, 'route_44');
      expect(route.number, equals('44'));
      expect(route.name, equals('CBD - Githurai'));
      expect(route.sacco, equals('Super Metro'));
    });

    test('WaitReportModel creates from map correctly', () {
      final now = DateTime.now();
      final map = {
        'stage_id': 'kencom',
        'route_id': 'route_44',
        'wait_time': 5,
        'timestamp': now,
        'day_of_week': now.weekday,
        'hour_of_day': now.hour,
        'user_id': 'test_user',
      };

      final report = WaitReportModel.fromMap(map, 'report_1');
      expect(report.stageId, equals('kencom'));
      expect(report.waitTime, equals(5));
    });
  });

  group('SeedData', () {
    test('returns stages list', () {
      final stages = SeedData.getStages();
      expect(stages, isNotEmpty);
      expect(stages.length, greaterThan(20));
    });

    test('returns routes list', () {
      final routes = SeedData.getRoutes();
      expect(routes, isNotEmpty);
      expect(routes.length, greaterThan(15));
    });

    test('getStagesByCorridor filters correctly', () {
      final cbdStages = SeedData.getStagesByCorridor('CBD');
      expect(cbdStages, isNotEmpty);
      for (final stage in cbdStages) {
        expect(stage.corridor, equals('CBD'));
      }
    });
  });

  group('AppConstants', () {
    test('has Nairobi green color', () {
      expect(AppConstants.nairobiGreen, isNotNull);
    });

    test('has app name', () {
      expect(AppConstants.appName, equals('NaVi'));
    });

    test('has corridors defined', () {
      expect(AppConstants.corridors, isNotEmpty);
      expect(AppConstants.corridors.keys, contains('Thika Road'));
    });
  });

}
