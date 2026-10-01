import 'package:test/test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/services/route_builder_service.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/search_result.dart';
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/models/fare_estimate.dart';

void main() {
  group('RouteBuilderService', () {
    // Origin is deliberately OFF the Kencom stage coordinate so the first
    // walking leg is real (>1 m). Boarding must resolve from the ORIGIN, and
    // destination lat/lng must stay off the declared stage so the final walk
    // leg is real too.
    const kOffStageOrigin = LatLng(-1.2842, 36.8172); // ~113 m from Kencom

    SearchResult railwaysDest({double lat = -1.2892, double lng = 36.8212}) {
      return SearchResult(
        query: 'Railways Bus Station',
        lat: lat,
        lng: lng,
        resolvedLabel: 'Railways Bus Station',
        matchedCorridorName: 'cbd',
        nearestStageName: 'Railways Bus Station',
        nearestStageLat: -1.2875,
        nearestStageLng: 36.8200,
        routeNumbers: ['24', '58', '10', '110', '114'],
        distanceToStageMeters: 0.0,
        source: SearchResultSource.exactStage,
      );
    }

    SearchResult githuraiDest({double lat = -1.2065, double lng = 36.9005}) {
      return SearchResult(
        query: 'Githurai 45 Stage',
        lat: lat,
        lng: lng,
        resolvedLabel: 'Githurai 45 Stage',
        matchedCorridorName: 'thika_road',
        nearestStageName: 'Githurai 45 Stage',
        nearestStageLat: -1.2083,
        nearestStageLng: 36.9000,
        routeNumbers: ['44', '45', '145', '146'],
        distanceToStageMeters: 0.0,
        source: SearchResultSource.exactStage,
      );
    }

    group('build', () {
      test('same corridor - returns 3 segments (walk, matatu, walk)', () async {
        final journey = await RouteBuilderService.build(
          origin: kOffStageOrigin,
          destination: railwaysDest(),
        );

        expect(journey.segments.length, equals(3));
        expect(journey.segments[0].mode, equals(SegmentMode.walk));
        expect(journey.segments[1].mode, equals(SegmentMode.matatu));
        expect(journey.segments[2].mode, equals(SegmentMode.walk));
      });

      test('same corridor - segment distances are non-zero and non-negative',
          () async {
        final destination = railwaysDest(lat: -1.2840, lng: 36.8220);

        final journey = await RouteBuilderService.build(
          origin: kOffStageOrigin,
          destination: destination,
        );

        for (final segment in journey.segments) {
          expect(segment.distanceMeters, greaterThan(0));
          expect(segment.estimatedDuration.inSeconds, greaterThan(0));
        }
      });

      test('walk segment has no route number', () async {
        final journey = await RouteBuilderService.build(
          origin: kOffStageOrigin,
          destination: railwaysDest(),
        );

        expect(journey.segments[0].routeNumber, isNull);
        expect(journey.segments[2].routeNumber, isNull);
      });

      test('matatu segment has route number', () async {
        final journey = await RouteBuilderService.build(
          origin: kOffStageOrigin,
          destination: railwaysDest(),
        );

        expect(journey.segments[1].routeNumber, isNotNull);
        expect(journey.segments[1].routeNumber, isNotEmpty);
      });

      test('different corridors - includes transfer segment', () async {
        // Origin on CBD corridor, destination on Thika Road corridor.
        final journey = await RouteBuilderService.build(
          origin: kOffStageOrigin,
          destination: githuraiDest(),
        );

        // Should have at least 3 segments, potentially more with transfer
        expect(journey.segments.length, greaterThanOrEqualTo(3));

        // Check for walk segments
        final walkSegments =
            journey.segments.where((s) => s.mode == SegmentMode.walk).toList();
        expect(walkSegments.length, greaterThanOrEqualTo(2)); // at least start and end walk
      });

      test('segment labels are descriptive', () async {
        final journey = await RouteBuilderService.build(
          origin: kOffStageOrigin,
          destination: railwaysDest(),
        );

        for (final segment in journey.segments) {
          expect(segment.label, isNotEmpty);
          expect(segment.label.length, greaterThan(5));
        }
      });

      test('walk segments use walking speed for duration', () async {
        final journey = await RouteBuilderService.build(
          origin: kOffStageOrigin,
          destination: railwaysDest(),
        );

        // Walking speed ~1.4 m/s, matatu ~20 km/h
        final walkSegments =
            journey.segments.where((s) => s.mode == SegmentMode.walk).toList();
        final matatuSegments =
            journey.segments.where((s) => s.mode == SegmentMode.matatu).toList();

        for (final walk in walkSegments) {
          final expectedWalkDuration =
              Duration(seconds: (walk.distanceMeters / 1.4).round());
          // Allow some tolerance
          expect(walk.estimatedDuration.inSeconds,
              closeTo(expectedWalkDuration.inSeconds, 5));
        }

        for (final matatu in matatuSegments) {
          const speedMs = 20.0 * 1000 / 3600; // 20 km/h in m/s
          final expectedMatatuDuration = Duration(
              seconds: (matatu.distanceMeters / speedMs).round());
          expect(matatu.estimatedDuration.inSeconds,
              closeTo(expectedMatatuDuration.inSeconds, 10));
        }
      });

      test('preferWalkingPaths forces walk-only for short trips', () async {
        // ~0.7 km crow-flies (CBD origin -> Railways) — well under the
        // 1.5 km walk-preference threshold.
        final journey = await RouteBuilderService.build(
          origin: kOffStageOrigin,
          destination: railwaysDest(),
          preferWalkingPaths: true,
        );

        expect(journey.segments.length, equals(1));
        expect(journey.segments[0].mode, equals(SegmentMode.walk));
        expect(journey.segments[0].label, 'Walk to Railways Bus Station');
        expect(journey.fareTotalKsh, equals(0));
      });

      test('preferWalkingPaths leaves long trips on the matatu network',
          () async {
        // Githurai is ~15 km away — walking is never preferred.
        final journey = await RouteBuilderService.build(
          origin: kOffStageOrigin,
          destination: githuraiDest(),
          preferWalkingPaths: true,
        );

        expect(journey.segments.length, greaterThanOrEqualTo(2));
        expect(journey.segments.any((s) => s.mode == SegmentMode.matatu),
            isTrue);
      });

      test('avoidBusyJunctions reroutes around a busy boarding corridor',
          () async {
        // Origin's nearest stage is Kencom (cbd = busy). Destination rides
        // Waiyaki Way (quiet) whose nearest stage to the origin is ~600 m —
        // inside the bypass walk budget, so the trip should walk onto the
        // quiet corridor instead of boarding in the CBD.
        final destination = SearchResult(
          query: 'Westlands Roundabout Stage',
          lat: -1.2722,
          lng: 36.8080,
          resolvedLabel: 'Westlands Roundabout Stage',
          matchedCorridorName: 'waiyaki_way',
          nearestStageName: 'Westlands Roundabout Stage',
          nearestStageLat: -1.2730,
          nearestStageLng: 36.8090,
          routeNumbers: ['105', '106', '107'],
          distanceToStageMeters: 0.0,
          source: SearchResultSource.exactStage,
        );

        final journey = await RouteBuilderService.build(
          origin: kOffStageOrigin,
          destination: destination,
          avoidBusyJunctions: true,
        );

        expect(journey.segments.length, equals(3));
        expect(journey.segments[0].mode, equals(SegmentMode.walk));
        expect(journey.segments[1].mode, equals(SegmentMode.matatu));
        expect(journey.segments[2].mode, equals(SegmentMode.walk));

        // Must NOT board at the busy Kencom junction.
        expect(
          journey.segments[0].label,
          isNot('Walk to Kencom Bus Station'),
        );
        expect(journey.segments[0].endPoint,
            equals(journey.segments[1].startPoint));
        expect(journey.segments[1].label,
            'Ride Route 105 to Westlands Roundabout Stage');
        // The bypass ride is chained to the final walk, all distances real.
        expect(journey.segments[1].endPoint,
            equals(journey.segments[2].startPoint));
        expect(journey.segments[0].distanceMeters, greaterThan(0));
        expect(journey.segments[2].distanceMeters, greaterThan(0));
      });

      test('avoidBusyJunctions keeps the normal route when the destination '
          'corridor is too far to walk to', () async {
        // Langata Road (quiet) nearest stage is ~2.5 km from the origin —
        // beyond the bypass budget, so no smarter re-route is possible and
        // the standard multi-corridor build must still win.
        final destination = SearchResult(
          query: 'Ngong / Langata Junction',
          lat: -1.2942,
          lng: 36.7955,
          resolvedLabel: 'Ngong / Langata Junction',
          matchedCorridorName: 'langata_road',
          nearestStageName: 'Ngong / Langata Junction',
          nearestStageLat: -1.2950,
          nearestStageLng: 36.7950,
          routeNumbers: ['125', '126', '5'],
          distanceToStageMeters: 0.0,
          source: SearchResultSource.exactStage,
        );

        final journey = await RouteBuilderService.build(
          origin: kOffStageOrigin,
          destination: destination,
          avoidBusyJunctions: true,
        );

        expect(journey.segments.length, greaterThanOrEqualTo(2));
        expect(journey.segments.first.mode, equals(SegmentMode.walk));
        expect(journey.segments.any((s) => s.mode == SegmentMode.matatu),
            isTrue);
      });

      test('boarding stage anchors to ORIGIN, alighting to DESTINATION '
          '(distinct stages for a cross-town hop)', () async {
        // Origin near Makadara on Jogoo Road; destination "past Buru Buru".
        const origin = LatLng(-1.2910, 36.8410);
        final destination = SearchResult(
          query: 'Utawala Plaza',
          lat: -1.2820,
          lng: 36.8680,
          resolvedLabel: 'Utawala Plaza',
          matchedCorridorName: 'jogoo_road',
          nearestStageName: 'Buru Buru Market Stage',
          nearestStageLat: -1.2850,
          nearestStageLng: 36.8700,
          routeNumbers: ['58', '10'],
          distanceToStageMeters: 0.0,
          source: SearchResultSource.mapboxGeocode,
        );

        final journey = await RouteBuilderService.build(
          origin: origin,
          destination: destination,
        );

        expect(journey.segments.length, equals(3));
        expect(journey.segments[0].mode, equals(SegmentMode.walk));
        expect(journey.segments[1].mode, equals(SegmentMode.matatu));
        expect(journey.segments[2].mode, equals(SegmentMode.walk));

        // Boarding must be the ORIGIN-side stage (Makadara), not the
        // destination's stage.
        expect(journey.segments[0].label, 'Walk to Makadara Stage');
        // Alighting is the DESTINATION-side stage (Buru Buru Market).
        expect(journey.segments[2].label, 'Walk to Utawala Plaza');
        // The three named controls are genuinely distinct — no "same stage"
        // repetition.
        final labels =
            journey.segments.map((s) => s.label).toSet();
        expect(labels.length, equals(3));

        // Segments chain end-to-end and every walk is real.
        expect(journey.segments[0].endPoint,
            equals(journey.segments[1].startPoint));
        expect(journey.segments[1].endPoint,
            equals(journey.segments[2].startPoint));
        expect(journey.segments[0].distanceMeters, greaterThanOrEqualTo(1.0));
        expect(journey.segments[2].distanceMeters, greaterThanOrEqualTo(1.0));
      });

      test('same stage for origin and destination yields walk-only route',
          () async {
        // Origin near Makadara; destination IS Makadara Stage.
        const origin = LatLng(-1.2910, 36.8410);
        final destination = SearchResult(
          query: 'Makadara Stage',
          lat: -1.2900,
          lng: 36.8400,
          resolvedLabel: 'Makadara Stage',
          matchedCorridorName: 'jogoo_road',
          nearestStageName: 'Makadara Stage',
          nearestStageLat: -1.2900,
          nearestStageLng: 36.8400,
          routeNumbers: ['58', '10', '34'],
          distanceToStageMeters: 0.0,
          source: SearchResultSource.exactStage,
        );

        final journey = await RouteBuilderService.build(
          origin: origin,
          destination: destination,
        );

        // A matatu ride to the very stage you walked to is never sensible.
        expect(journey.segments.length, equals(1));
        expect(journey.segments[0].mode, equals(SegmentMode.walk));
        expect(journey.segments[0].label, 'Walk to Makadara Stage');
        expect(journey.segments[0].distanceMeters, greaterThanOrEqualTo(1.0));
        expect(journey.fareTotalKsh, equals(0));
      });
    });

    group('ActiveJourney', () {
      test('progress tracking works', () {
        final segments = [
          RouteSegment.walk(
            label: 'Walk to Stage A',
            coordinates: [
              const LatLng(-1.2833, 36.8167),
              const LatLng(-1.2850, 36.8183),
            ],
            startPoint: const LatLng(-1.2833, 36.8167),
            endPoint: const LatLng(-1.2850, 36.8183),
          ),
        ];

        final journey = ActiveJourney(segments: segments);
        
        // At start
        expect(journey.currentSegmentIndex, equals(0));
        expect(journey.progressAlongCurrentSegment, equals(0.0));
        expect(journey.isComplete, isFalse);
      });

      test('completed segments tracking', () {
        final segments = [
          RouteSegment.walk(
            label: 'Walk to Stage A',
            coordinates: [
              const LatLng(-1.2833, 36.8167),
              const LatLng(-1.2850, 36.8183),
            ],
            startPoint: const LatLng(-1.2833, 36.8167),
            endPoint: const LatLng(-1.2850, 36.8183),
          ),
          RouteSegment.matatu(
            label: 'Ride Route 46',
            coordinates: [
              const LatLng(-1.2850, 36.8183),
              const LatLng(-1.2875, 36.8200),
            ],
            routeNumber: '46',
            startPoint: const LatLng(-1.2850, 36.8183),
            endPoint: const LatLng(-1.2875, 36.8200),
          ),
        ];

        final journey = ActiveJourney(segments: segments);
        
        // Simulate reaching end of first segment
        journey.updatePosition(segments[0].endPoint);
        
        expect(journey.currentSegmentIndex, equals(1));
        expect(journey.completedSegments.length, equals(1));
        expect(journey.upcomingSegments.length, equals(0));
      });

      test('getTraveledCoordinates returns correct coordinates', () {
        final segments = [
          RouteSegment.walk(
            label: 'Walk to Stage A',
            coordinates: [
              const LatLng(-1.2833, 36.8167),
              const LatLng(-1.2841, 36.8175),
              const LatLng(-1.2850, 36.8183),
            ],
            startPoint: const LatLng(-1.2833, 36.8167),
            endPoint: const LatLng(-1.2850, 36.8183),
          ),
        ];

        final journey = ActiveJourney(segments: segments);
        
        // Move halfway
        journey.updatePosition(const LatLng(-1.2841, 36.8175));
        
        final traveled = journey.getTraveledCoordinates();
        expect(traveled.length, greaterThan(0));
      });

      test('getCurrentSegmentRemainingCoordinates returns remaining', () {
        final segments = [
          RouteSegment.walk(
            label: 'Walk to Stage A',
            coordinates: [
              const LatLng(-1.2833, 36.8167),
              const LatLng(-1.2841, 36.8175),
              const LatLng(-1.2850, 36.8183),
            ],
            startPoint: const LatLng(-1.2833, 36.8167),
            endPoint: const LatLng(-1.2850, 36.8183),
          ),
        ];

        final journey = ActiveJourney(segments: segments);
        
        // At start - should return all
        var remaining = journey.getCurrentSegmentRemainingCoordinates();
        expect(remaining.length, equals(3));
        
        // Move to middle
        journey.updatePosition(const LatLng(-1.2841, 36.8175));
        remaining = journey.getCurrentSegmentRemainingCoordinates();
        expect(remaining.length, lessThanOrEqualTo(3));
        expect(remaining.length, greaterThanOrEqualTo(1));
      });

      test('total distance and duration calculations', () {
        final segments = [
          RouteSegment.walk(
            label: 'Walk to Stage A',
            coordinates: [
              const LatLng(-1.2833, 36.8167),
              const LatLng(-1.2850, 36.8183),
            ],
            startPoint: const LatLng(-1.2833, 36.8167),
            endPoint: const LatLng(-1.2850, 36.8183),
          ),
          RouteSegment.matatu(
            label: 'Ride Route 46',
            coordinates: [
              const LatLng(-1.2850, 36.8183),
              const LatLng(-1.2875, 36.8200),
            ],
            routeNumber: '46',
            startPoint: const LatLng(-1.2850, 36.8183),
            endPoint: const LatLng(-1.2875, 36.8200),
          ),
        ];

        final journey = ActiveJourney(segments: segments);
        
        expect(journey.totalDistanceMeters, greaterThan(0));
        expect(journey.totalEstimatedDuration.inSeconds, greaterThan(0));
      });

      test('remaining distance and duration shrink as the trip progresses', () {
        final segments = [
          RouteSegment.walk(
            label: 'Walk to Stage A',
            coordinates: [
              const LatLng(-1.2833, 36.8167),
              const LatLng(-1.2850, 36.8183),
            ],
            startPoint: const LatLng(-1.2833, 36.8167),
            endPoint: const LatLng(-1.2850, 36.8183),
          ),
          RouteSegment.matatu(
            label: 'Ride Route 46 to Stage B',
            coordinates: [
              const LatLng(-1.2850, 36.8183),
              const LatLng(-1.2875, 36.8200),
            ],
            routeNumber: '46',
            startPoint: const LatLng(-1.2850, 36.8183),
            endPoint: const LatLng(-1.2875, 36.8200),
          ),
        ];

        final journey = ActiveJourney(segments: segments);
        final total = journey.totalDistanceMeters;
        final totalDuration = journey.totalEstimatedDuration.inSeconds;

        expect(journey.remainingDistanceMeters, closeTo(total, 0.001));
        expect(journey.remainingDuration.inSeconds, equals(totalDuration));

        // Halfway along the first segment: remaining must be smaller.
        final mid = LatLng(
          (segments[0].startPoint.latitude + segments[0].endPoint.latitude) / 2,
          (segments[0].startPoint.longitude + segments[0].endPoint.longitude) / 2,
        );
        journey.updatePosition(mid);

        expect(journey.remainingDistanceMeters, lessThan(total));
        expect(journey.remainingDistanceMeters, greaterThan(0));
        expect(journey.remainingDuration.inSeconds, lessThan(totalDuration));
        expect(journey.remainingDuration.inSeconds, greaterThan(0));

        // Reach the end of the first segment -> move onto the matatu leg.
        journey.updatePosition(segments[0].endPoint);
        expect(journey.currentSegmentIndex, equals(1));
        expect(journey.remainingDistanceMeters, lessThan(total));

        // Complete: zero remaining.
        journey.updatePosition(segments[1].endPoint);
        expect(journey.isComplete, isTrue);
        expect(journey.remainingDistanceMeters, equals(0));
        expect(journey.remainingDuration, equals(Duration.zero));
      });

      test('summary getters isolate walk vs matatu metrics', () {
        final walk = RouteSegment.walk(
          label: 'Walk to Stage A',
          coordinates: [
            const LatLng(-1.2833, 36.8167),
            const LatLng(-1.2850, 36.8183),
          ],
          startPoint: const LatLng(-1.2833, 36.8167),
          endPoint: const LatLng(-1.2850, 36.8183),
        );
        final matatu = RouteSegment.matatu(
          label: 'Ride Route 46',
          coordinates: [
            const LatLng(-1.2850, 36.8183),
            const LatLng(-1.2875, 36.8200),
          ],
          routeNumber: '46',
          startPoint: const LatLng(-1.2850, 36.8183),
          endPoint: const LatLng(-1.2875, 36.8200),
        );

        final journey = ActiveJourney(segments: [walk, matatu]);

        // Walking metrics must exclude the matatu leg and vice versa — the
        // two pre-trip surfaces (header + bottom bar) depend on this split.
        expect(journey.walkDistanceMeters, closeTo(walk.distanceMeters, 0.001));
        expect(journey.walkDuration, equals(walk.estimatedDuration));
        expect(journey.matatuDuration, equals(matatu.estimatedDuration));
        expect(
          journey.totalEstimatedDuration,
          equals(walk.estimatedDuration + matatu.estimatedDuration),
        );
      });

      test('fareTotalKsh sums segment fare estimates (matatu legs never free)',
          () {
        final walk = RouteSegment.walk(
          label: 'Walk to Stage A',
          coordinates: [
            const LatLng(-1.2833, 36.8167),
            const LatLng(-1.2850, 36.8183),
          ],
          startPoint: const LatLng(-1.2833, 36.8167),
          endPoint: const LatLng(-1.2850, 36.8183),
        ).copyWith(
          fareEstimate:
              FareEstimate.walking(timeOfDay: TimeOfDay.offPeak),
        );
        final matatu = RouteSegment.matatu(
          label: 'Ride Route 46',
          coordinates: [
            const LatLng(-1.2850, 36.8183),
            const LatLng(-1.2875, 36.8200),
          ],
          routeNumber: '46',
          startPoint: const LatLng(-1.2850, 36.8183),
          endPoint: const LatLng(-1.2875, 36.8200),
        ).copyWith(
          fareEstimate: FareEstimate.matatu(
            amountKsh: 30,
            tier: FareTier.short,
            timeOfDay: TimeOfDay.offPeak,
          ),
        );

        final journey = ActiveJourney(segments: [walk, matatu]);

        // Walking contributes 0; a matatu-inclusive journey is never KSh 0.
        expect(journey.fareTotalKsh, equals(30));
      });

      test('pure-walk journey fare is 0', () {
        final walk = RouteSegment.walk(
          label: 'Walk to Stage A',
          coordinates: [
            const LatLng(-1.2833, 36.8167),
            const LatLng(-1.2850, 36.8183),
          ],
          startPoint: const LatLng(-1.2833, 36.8167),
          endPoint: const LatLng(-1.2850, 36.8183),
        ).copyWith(
          fareEstimate:
              FareEstimate.walking(timeOfDay: TimeOfDay.offPeak),
        );

        final journey = ActiveJourney(segments: [walk]);

        // Walking is the only mode that may be free.
        expect(journey.fareTotalKsh, equals(0));
      });
    });

    group('RouteSegment', () {
      test('walk factory creates correct segment', () {
        final segment = RouteSegment.walk(
          label: 'Walk to stage',
          coordinates: [
            const LatLng(-1.2833, 36.8167),
            const LatLng(-1.2850, 36.8183),
          ],
          startPoint: const LatLng(-1.2833, 36.8167),
          endPoint: const LatLng(-1.2850, 36.8183),
        );

        expect(segment.mode, equals(SegmentMode.walk));
        expect(segment.routeNumber, isNull);
        expect(segment.distanceMeters, greaterThan(0));
        expect(segment.estimatedDuration.inSeconds, greaterThan(0));
      });

      test('matatu factory creates correct segment', () {
        final segment = RouteSegment.matatu(
          label: 'Ride Route 46',
          coordinates: [
            const LatLng(-1.2850, 36.8183),
            const LatLng(-1.2875, 36.8200),
          ],
          routeNumber: '46',
          startPoint: const LatLng(-1.2850, 36.8183),
          endPoint: const LatLng(-1.2875, 36.8200),
        );

        expect(segment.mode, equals(SegmentMode.matatu));
        expect(segment.routeNumber, equals('46'));
        expect(segment.distanceMeters, greaterThan(0));
        expect(segment.estimatedDuration.inSeconds, greaterThan(0));
      });

      test('toGeoJson produces valid GeoJSON', () {
        final segment = RouteSegment.walk(
          label: 'Walk to stage',
          coordinates: [
            const LatLng(-1.2833, 36.8167),
            const LatLng(-1.2850, 36.8183),
          ],
          startPoint: const LatLng(-1.2833, 36.8167),
          endPoint: const LatLng(-1.2850, 36.8183),
        );

        final geoJson = segment.toGeoJson();
        
        expect(geoJson['type'], equals('Feature'));
        expect(geoJson['geometry']['type'], equals('LineString'));
        expect(geoJson['geometry']['coordinates'], isA<List>());
        expect(geoJson['properties']['mode'], equals('walk'));
      });
    });
  });
}