import 'package:flutter_test/flutter_test.dart';

import 'package:navi_app/data/seed_data.dart';
import 'package:navi_app/services/stage_route_summary.dart';

Map<String, dynamic> direction(String headsign, List<String> stages) => {
      'direction_id': '0',
      'headsign': headsign,
      'ordered_stages': stages,
      'stage_count': stages.length,
    };

Map<String, dynamic> route(
  String number, {
  List<Map<String, dynamic>> directions = const [],
  List<dynamic>? peak,
  List<dynamic>? offpeak,
  bool noHeadways = false,
}) =>
    {
      'route_id': 'id_$number',
      'route_number': number,
      'route_name': 'Route $number',
      'directions': directions,
      if (!noHeadways) 'peak_headway_min_range': peak ?? <dynamic>[5, 5],
      if (!noHeadways) 'offpeak_headway_min_range': offpeak ?? <dynamic>[5, 15],
    };

/// An absolute instant whose Nairobi wall clock (UTC+3) reads [hour]:[minute].
DateTime nairobi(int hour, int minute) =>
    DateTime.utc(2026, 1, 5, hour, minute).subtract(const Duration(hours: 3));

final List<dynamic> fixtureRoutes = [
  route(
    '24',
    directions: [
      direction('Karen', ['ambassadeur', 'ad_mall']),
      direction('Ambassadeur', ['ad_mall', 'ambassadeur']),
    ],
    peak: [6, 8],
    offpeak: [10, 15],
  ),
  route(
    '24C',
    directions: [
      direction('Kencom', ['ambassadeur']),
      direction('Hardy', ['ambassadeur']),
    ],
  ),
  route(
    '34B',
    directions: [direction('Jacaranda', ['ambassadeur'])],
    noHeadways: true,
  ),
  route('10', directions: [direction('Maringo', ['makadara_1'])]),
  route(
    '58',
    directions: [
      direction('Ambassadeur', ['makadara-dc_jogoo_road']),
      direction('Buruburu', ['makadara-dc']),
    ],
  ),
  route('110AK', directions: [direction('Kitengela', ['makadara_2'])]),
  route(
    '26',
    directions: [
      direction('Kariobangi', ['makadara_1']),
      direction('Makadara', ['makadara-mwisho']),
    ],
  ),
  route('40', directions: [direction('Umoja', ['unrelated_stage'])]),
];

List<String> rowNumbers(List<StageRouteSummary> rows) =>
    rows.map((row) => row.routeNumber).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isPeakTime', () {
    test('morning band 06:30-09:30 inclusive', () {
      expect(StageRouteSummaries.isPeakTime(nairobi(6, 29)), isFalse);
      expect(StageRouteSummaries.isPeakTime(nairobi(6, 30)), isTrue);
      expect(StageRouteSummaries.isPeakTime(nairobi(9, 30)), isTrue);
      expect(StageRouteSummaries.isPeakTime(nairobi(9, 31)), isFalse);
    });

    test('evening band 16:30-20:00 inclusive', () {
      expect(StageRouteSummaries.isPeakTime(nairobi(16, 29)), isFalse);
      expect(StageRouteSummaries.isPeakTime(nairobi(16, 30)), isTrue);
      expect(StageRouteSummaries.isPeakTime(nairobi(20, 0)), isTrue);
      expect(StageRouteSummaries.isPeakTime(nairobi(20, 1)), isFalse);
    });

    test('midday and night are off-peak', () {
      expect(StageRouteSummaries.isPeakTime(nairobi(12, 0)), isFalse);
      expect(StageRouteSummaries.isPeakTime(nairobi(0, 30)), isFalse);
    });

    test('converts UTC instants to Nairobi wall clock', () {
      // 03:30 UTC = 06:30 Nairobi, the first peak minute.
      expect(StageRouteSummaries.isPeakTime(DateTime.utc(2026, 1, 5, 3, 30)),
          isTrue);
      expect(StageRouteSummaries.isPeakTime(DateTime.utc(2026, 1, 5, 3, 29)),
          isFalse);
    });
  });

  group('headwayTextForRange', () {
    test('single-value range reads "every 5 min"', () {
      expect(
        StageRouteSummaries.headwayTextForRange([5, 5]),
        'A matatu comes every 5 min right now',
      );
    });

    test('range reads "every 5-15 min"', () {
      expect(
        StageRouteSummaries.headwayTextForRange([5, 15]),
        'A matatu comes every 5-15 min right now',
      );
    });

    test('reversed range is normalised', () {
      expect(
        StageRouteSummaries.headwayTextForRange([15, 5]),
        'A matatu comes every 5-15 min right now',
      );
    });

    test('fractional values keep one decimal', () {
      expect(
        StageRouteSummaries.headwayTextForRange([5.5, 15]),
        'A matatu comes every 5.5-15 min right now',
      );
    });

    test('absent or malformed ranges fall back to the honest message', () {
      expect(StageRouteSummaries.headwayTextForRange(null),
          StageRouteSummaries.noFrequencyText);
      expect(StageRouteSummaries.headwayTextForRange([]),
          StageRouteSummaries.noFrequencyText);
      expect(StageRouteSummaries.headwayTextForRange([5]),
          StageRouteSummaries.noFrequencyText);
      expect(StageRouteSummaries.headwayTextForRange(['5', '15']),
          StageRouteSummaries.noFrequencyText);
      expect(StageRouteSummaries.headwayTextForRange({'low': 5}),
          StageRouteSummaries.noFrequencyText);
    });
  });

  group('summarize resolution', () {
    test('exact stage id matches even when the hand route list is stale',
        () {
      final rows = StageRouteSummaries.summarize(
        routes: fixtureRoutes,
        stageId: 'ambassadeur',
        stageName: 'Ambassadeur Bus Stop',
        stageRouteNumbers: const ['44', '45', '111', '58', '33', '34'],
        now: nairobi(12, 0),
      );

      expect(rowNumbers(rows), ['24', '24C', '34B']);
      expect(rows[0].headsign, 'Karen / Ambassadeur');
      expect(rows[1].headsign, 'Kencom / Hardy');
      expect(rows[2].headsign, 'Jacaranda');
    });

    test('name core resolves the makadara family, narrowed to known routes',
        () {
      final rows = StageRouteSummaries.summarize(
        routes: fixtureRoutes,
        stageId: 'makadara',
        stageName: 'Makadara Stage',
        stageRouteNumbers: const ['58', '10', '34'],
        now: nairobi(12, 0),
      );

      expect(rowNumbers(rows), ['10', '58', '26']);
      expect(rows[0].headsign, 'Maringo');
      expect(rows[1].headsign, 'Ambassadeur / Buruburu');
      // The makadara-mwisho direction of 26 belongs to a family member the
      // known-route filter dropped, so it must not leak into the headsign.
      expect(rows[2].headsign, 'Kariobangi');
      expect(rowNumbers(rows), isNot(contains('110AK')));
    });

    test('known routes matching nothing keep the whole name family', () {
      final rows = StageRouteSummaries.summarize(
        routes: fixtureRoutes,
        stageId: 'makadara',
        stageName: 'Makadara Stage',
        stageRouteNumbers: const ['999'],
        now: nairobi(12, 0),
      );

      expect(rowNumbers(rows), containsAll(['10', '58', '110AK', '26']));
    });

    test('no id or name match yields no rows', () {
      final rows = StageRouteSummaries.summarize(
        routes: fixtureRoutes,
        stageId: 'nowhere',
        stageName: 'Nowhere Stage',
        now: nairobi(12, 0),
      );

      expect(rows, isEmpty);
    });

    test('a direction without a headsign falls back honestly', () {
      final routes = [
        route('99', directions: [direction('', ['ambassadeur'])]),
      ];
      final rows = StageRouteSummaries.summarize(
        routes: routes,
        stageId: 'ambassadeur',
        now: nairobi(12, 0),
      );

      expect(rows.single.headsign, 'destination not recorded yet');
    });

    test('rows follow routes.json order', () {
      final rows = StageRouteSummaries.summarize(
        routes: fixtureRoutes,
        stageId: 'ambassadeur',
        stageName: 'Ambassadeur',
        now: nairobi(12, 0),
      );

      expect(rowNumbers(rows), ['24', '24C', '34B']);
    });
  });

  group('summarize headway band selection', () {
    test('peak instant uses peak ranges', () {
      final rows = StageRouteSummaries.summarize(
        routes: fixtureRoutes,
        stageId: 'ambassadeur',
        now: nairobi(8, 0),
      );

      expect(rows[0].headwayText, 'A matatu comes every 6-8 min right now');
      expect(rows[1].headwayText, 'A matatu comes every 5 min right now');
    });

    test('off-peak instant uses off-peak ranges', () {
      final rows = StageRouteSummaries.summarize(
        routes: fixtureRoutes,
        stageId: 'ambassadeur',
        now: nairobi(12, 0),
      );

      expect(rows[0].headwayText, 'A matatu comes every 10-15 min right now');
    });

    test('a route without headways reports the honest fallback per row', () {
      final rows = StageRouteSummaries.summarize(
        routes: fixtureRoutes,
        stageId: 'ambassadeur',
        now: nairobi(12, 0),
      );

      final withoutHeadways =
          rows.firstWhere((row) => row.routeNumber == '34B');
      expect(withoutHeadways.headwayText, StageRouteSummaries.noFrequencyText);
    });
  });

  group('stageFrequencyText', () {
    test('widest range across serving routes, per band', () {
      final peak = StageRouteSummaries.stageFrequencyText(
        routes: fixtureRoutes,
        stageId: 'ambassadeur',
        now: nairobi(8, 0),
      );
      expect(peak, 'A matatu comes every 5-8 min right now');

      final offPeak = StageRouteSummaries.stageFrequencyText(
        routes: fixtureRoutes,
        stageId: 'ambassadeur',
        now: nairobi(12, 0),
      );
      expect(offPeak, 'A matatu comes every 5-15 min right now');
    });

    test('no serving routes means no frequency', () {
      expect(
        StageRouteSummaries.stageFrequencyText(
          routes: fixtureRoutes,
          stageId: 'nowhere',
          now: nairobi(12, 0),
        ),
        StageRouteSummaries.noFrequencyText,
      );
    });

    test('serving routes with no headways mean no frequency', () {
      final routes = [
        route('99', directions: [direction('Kariobangi', ['ambassadeur'])],
            noHeadways: true),
      ];
      expect(
        StageRouteSummaries.stageFrequencyText(
          routes: routes,
          stageId: 'ambassadeur',
          now: nairobi(12, 0),
        ),
        StageRouteSummaries.noFrequencyText,
      );
    });
  });

  group('real GTFS bundle', () {
    final seedStages = SeedData.getStages();
    final makadara =
        seedStages.firstWhere((stage) => stage.id == 'makadara');
    final ambassadeur =
        seedStages.firstWhere((stage) => stage.id == 'ambassadeur');

    test('loadForStage returns structurally complete rows', () async {
      final rows = await StageRouteSummaries.loadForStage(makadara);
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(row.routeNumber, isNotEmpty);
        expect(row.headsign, isNotEmpty);
        expect(row.headwayText, isNotEmpty);
      }
    });

    test('loadForStage resolves Ambassadeur by exact id', () async {
      final rows = await StageRouteSummaries.loadForStage(ambassadeur);
      expect(rows, isNotEmpty);
    });

    test('loadStageFrequency returns a non-empty sentence', () async {
      final frequency =
          await StageRouteSummaries.loadStageFrequency(makadara);
      expect(frequency, isNotEmpty);
    });
  });
}
