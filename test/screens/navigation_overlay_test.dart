import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/design/navi_colors.dart';
import 'package:navi_app/models/active_journey.dart';
import 'package:navi_app/models/fare_estimate.dart' as fare;
import 'package:navi_app/models/route_segment.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/screens/navigation_overlay.dart';
import 'package:navi_app/widgets/active_nav/active_nav_data.dart';
import 'package:navi_app/widgets/active_nav/active_nav_panel.dart';
import 'package:navi_app/widgets/active_nav/active_nav_theme.dart';
import 'package:navi_app/widgets/active_nav/journey_timeline.dart';
import 'package:navi_app/widgets/active_nav/nav_banner.dart';
import 'package:navi_app/widgets/active_nav/nav_map_controls.dart';
import 'package:navi_app/widgets/pre_trip_card.dart' show PreTripExtras;

void main() {
  const origin = LatLng(-1.2833, 36.8167);
  const boarding = LatLng(-1.2850, 36.8183);
  const alighting = LatLng(-1.2875, 36.8200);
  const destination = LatLng(-1.2890, 36.8220);

  final stages = [
    StageModel(
      id: 'kariobangi',
      name: 'Kariobangi',
      lat: boarding.latitude,
      lng: boarding.longitude,
      corridor: 'Outer Ring',
      routes: const ['46'],
    ),
    StageModel(
      id: 'makadara',
      name: 'Makadara',
      lat: alighting.latitude,
      lng: alighting.longitude,
      corridor: 'Jogoo',
      routes: const ['46'],
    ),
  ];

  ActiveJourney walkRideWalk({int currentSegmentIndex = 0}) {
    return ActiveJourney(
      segments: [
        RouteSegment.walk(
          label: 'Walk to Kariobangi Stage',
          coordinates: [origin, boarding],
          startPoint: origin,
          endPoint: boarding,
        ),
        RouteSegment.matatu(
          label: 'Ride Route 46 to Makadara',
          coordinates: [boarding, alighting],
          routeNumber: '46',
          fromStageId: 'kariobangi',
          toStageId: 'makadara',
          startPoint: boarding,
          endPoint: alighting,
        ),
        RouteSegment.walk(
          label: 'Walk to destination',
          coordinates: [alighting, destination],
          startPoint: alighting,
          endPoint: destination,
        ),
      ],
      currentSegmentIndex: currentSegmentIndex,
    );
  }

  /// Same journey with a real calculator-shaped fare estimate stamped on the
  /// matatu leg, so the panel's fare row has a truthful amount to show.
  ActiveJourney walkRideWalkWithFare(int amountKsh) {
    final segments = walkRideWalk().segments.toList();
    segments[1] = segments[1].copyWith(
      fareEstimate: fare.FareEstimate.matatu(
        amountKsh: amountKsh,
        tier: fare.FareTier.short,
        timeOfDay: fare.TimeOfDay.offPeak,
      ),
    );
    return ActiveJourney(segments: segments);
  }

  Widget overlays({
    ActiveJourney? journey,
    String? proximityMessage,
    VoidCallback? onDismissProximity,
    VoidCallback? onEndTrip,
    ValueChanged<bool>? onToggleVoiceGuidance,
  }) {
    return NavigationOverlay(
      map: const ColoredBox(
        key: Key('mapZone'),
        color: Color(0xFFCCCCCC),
      ),
      journey: journey ?? walkRideWalk(),
      stages: stages,
      proximityMessage: proximityMessage,
      onDismissProximity: onDismissProximity,
      voiceGuidanceEnabled: true,
      onToggleVoiceGuidance: onToggleVoiceGuidance ?? (_) {},
      onEndTrip: onEndTrip ?? () {},
      onZoomIn: () {},
      onZoomOut: () {},
      onResetBearing: () {},
    );
  }

  Future<void> pumpOverlay(
    WidgetTester tester, {
    ActiveJourney? journey,
    String? proximityMessage,
    VoidCallback? onDismissProximity,
    VoidCallback? onEndTrip,
    ValueChanged<bool>? onToggleVoiceGuidance,
    bool dark = false,
    Size size = const Size(400, 700),
    bool disableAnimations = true,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: overlays(
            journey: journey,
            proximityMessage: proximityMessage,
            onDismissProximity: onDismissProximity,
            onEndTrip: onEndTrip,
            onToggleVoiceGuidance: onToggleVoiceGuidance,
          ),
        ),
      ),
    ));
  }

  Widget panel(
    ActiveNavData data, {
    required bool expanded,
    bool dark = false,
    VoidCallback? onEndTrip,
  }) {
    return MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        body: ActiveNavPanel(
          data: data,
          scrollController: ScrollController(),
          expanded: expanded,
          onEndTrip: onEndTrip ?? () {},
        ),
      ),
    );
  }

  group('map / panel split', () {
    testWidgets('map keeps 55-60% of the screen above the collapsed panel',
        (tester) async {
      await pumpOverlay(tester);

      final panel = tester.getRect(find.byKey(const Key('activeNavPanel')));
      final visibleMap = panel.top;

      expect(visibleMap / 700, inInclusiveRange(0.55, 0.62));
      expect(visibleMap, greaterThanOrEqualTo(300),
          reason: 'the map always keeps at least 300dp above the panel');
      expect(find.byKey(const Key('mapZone')), findsOneWidget);
    });

    testWidgets('panel opens just tall enough for its content', (tester) async {
      const size = Size(400, 900);
      expect(NavigationOverlay.initialExtentFor(size),
          closeTo(NavigationOverlay.collapsedContentPx / 900, 0.001));
      expect(
        NavigationOverlay.initialExtentFor(
          size,
          bottomInset: 24,
          hasFare: true,
        ),
        closeTo(
          (NavigationOverlay.collapsedContentPx +
                  24 +
                  NavigationOverlay.fareRowPx) /
              900,
          0.001,
        ),
      );
      expect(NavigationOverlay.maxExtent, 0.80);
      expect(NavigationOverlay.minExtent,
          lessThan(NavigationOverlay.initialExtentFor(size)));
    });

    testWidgets('360dp width lays out without overflow', (tester) async {
      await pumpOverlay(tester, size: const Size(360, 640));

      expect(tester.takeException(), isNull);
      final banner = tester.getRect(find.byType(NavInstructionBanner));
      expect(banner.width, 360 - 32, reason: '16dp side margins');

      // The collapsed sheet shows the current step and the next two without
      // clipping, and its height is the content height — no empty gap above
      // the End Journey button on a 360dp phone.
      final panel = tester.getRect(find.byKey(const Key('activeNavPanel')));
      expect(panel.height, closeTo(NavigationOverlay.collapsedContentPx, 1));
      final rows = find.byType(NavTimelineRow);
      expect(rows, findsNWidgets(3));
      final endButton =
          tester.getRect(find.widgetWithText(FilledButton, 'End Journey'));
      expect(
          tester.getRect(rows.last).bottom, lessThanOrEqualTo(endButton.top));
      final bottomInset =
          MediaQuery.of(tester.element(find.byKey(const Key('activeNavPanel'))))
              .padding
              .bottom;
      expect(panel.bottom - endButton.bottom,
          inInclusiveRange(8, 20 + bottomInset),
          reason: 'the action sits at the bottom with only its inset');
    });

    testWidgets('412dp phone gives the freed space back to the map',
        (tester) async {
      await pumpOverlay(tester, size: const Size(412, 915));

      expect(tester.takeException(), isNull);
      final panel = tester.getRect(find.byKey(const Key('activeNavPanel')));
      expect(panel.height, closeTo(NavigationOverlay.collapsedContentPx, 1));
      expect(panel.top / 915, greaterThan(0.65),
          reason: 'a tall phone leaves more than two thirds to the map');

      final endButton =
          tester.getRect(find.widgetWithText(FilledButton, 'End Journey'));
      final bottomInset =
          MediaQuery.of(tester.element(find.byKey(const Key('activeNavPanel'))))
              .padding
              .bottom;
      expect(panel.bottom - endButton.bottom,
          inInclusiveRange(8, 20 + bottomInset),
          reason: 'the action sits at the bottom with only its inset');
      expect(find.byType(NavTimelineRow), findsNWidgets(3));
      expect(tester.getRect(find.byType(NavTimelineRow).last).bottom,
          lessThanOrEqualTo(endButton.top));
    });
  });

  group('map controls', () {
    testWidgets('float 16dp from the right edge, just above the panel',
        (tester) async {
      await pumpOverlay(tester);

      final rail = tester.getRect(find.byType(NavMapControls));
      final panel = tester.getRect(find.byKey(const Key('activeNavPanel')));
      expect(rail.right, 400 - 16);
      expect(rail.bottom, closeTo(panel.top - 16, 0.5));
      expect(
          rail.top,
          greaterThan(tester
              .getRect(
                find.byType(NavInstructionBanner),
              )
              .bottom));
    });

    testWidgets('voice button reports the flipped value', (tester) async {
      bool? value;
      await pumpOverlay(tester, onToggleVoiceGuidance: (v) => value = v);

      await tester.tap(find.byIcon(Icons.volume_up));
      expect(value, isFalse);
    });
  });

  group('instruction banner', () {
    testWidgets('walking leg without steps shows the walk instruction',
        (tester) async {
      await pumpOverlay(tester);

      final banner = find.byType(NavInstructionBanner);
      expect(
        find.descendant(
          of: banner,
          matching: find.text('Walk to Kariobangi Stage'),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(banner).height, ActiveNavTheme.bannerHeight);
      expect(
        find.descendant(
          of: banner,
          matching: find.text('Then board Route 46'),
        ),
        findsOneWidget,
        reason: 'the second line names the next real action',
      );
    });

    testWidgets('walking second line uses the real next route number',
        (tester) async {
      final segments = walkRideWalk().segments.toList();
      segments[1] = segments[1].copyWith(routeNumber: '69');
      await pumpOverlay(
        tester,
        journey: ActiveJourney(segments: segments),
      );

      expect(find.text('Then board Route 69'), findsOneWidget);
      expect(find.textContaining('Road'), findsNothing,
          reason: 'no road name is invented');
    });

    testWidgets('matatu leg shows the route and alighting stage',
        (tester) async {
      await pumpOverlay(tester, journey: walkRideWalk(currentSegmentIndex: 1));

      final banner = find.byType(NavInstructionBanner);
      expect(
        find.descendant(of: banner, matching: find.text('Stay on Route 46')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: banner, matching: find.text('Get off at Makadara')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: banner, matching: find.text('Ride Route 46 to Makadara')),
        findsNothing,
      );
    });

    testWidgets('after alighting the banner walks to the destination',
        (tester) async {
      await pumpOverlay(tester, journey: walkRideWalk(currentSegmentIndex: 2));

      final banner = find.byType(NavInstructionBanner);
      expect(
        find.descendant(
            of: banner, matching: find.text('Walk to your destination')),
        findsOneWidget,
      );
    });

    testWidgets('banner transition is 250ms unless animations are disabled',
        (tester) async {
      await pumpOverlay(tester, disableAnimations: false);
      final switcher =
          tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
      expect(switcher.duration, const Duration(milliseconds: 250));

      await pumpOverlay(tester);
      final reduced =
          tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
      expect(reduced.duration, Duration.zero);
    });
  });

  group('coordinate safety', () {
    testWidgets('a coordinate-fallback destination never renders raw',
        (tester) async {
      final journey = ActiveJourney(segments: [
        RouteSegment.walk(
          label: 'Walk to -1.285000, 36.818300',
          coordinates: [origin, destination],
          startPoint: origin,
          endPoint: destination,
        ),
      ]);
      await pumpOverlay(tester, journey: journey);

      expect(find.text('Walk to -1.285000, 36.818300'), findsNothing);
      expect(find.textContaining('-1.285000'), findsNothing);
      expect(find.text('Walk to your destination'), findsWidgets);
    });
  });

  group('proximity strip', () {
    testWidgets('amber strip docks under the banner, clear of the map centre',
        (tester) async {
      await pumpOverlay(tester,
          proximityMessage: 'Approaching Makadara - 100 m');

      final banner = tester.getRect(find.byType(NavInstructionBanner));
      final strip = tester.getRect(find.byType(NavProximityBanner));
      final panel = tester.getRect(find.byKey(const Key('activeNavPanel')));

      expect(find.text('Approaching Makadara - 100 m'), findsOneWidget);
      expect(strip.top, greaterThanOrEqualTo(banner.bottom));
      expect(strip.bottom, lessThan(700 / 2),
          reason: 'the strip never reaches the map centre');
      expect(strip.bottom, lessThanOrEqualTo(panel.top));
    });

    testWidgets('dismiss button fires the owner callback', (tester) async {
      var dismissed = false;
      await pumpOverlay(tester,
          proximityMessage: 'Approaching Makadara - 50 m',
          onDismissProximity: () => dismissed = true);

      await tester.tap(find.byIcon(Icons.close));
      expect(dismissed, isTrue);
    });

    testWidgets('hidden when there is no active alert', (tester) async {
      await pumpOverlay(tester);
      expect(find.byType(NavProximityBanner), findsNothing);
    });
  });

  group('timeline states', () {
    test('current, completed and upcoming are derived from the live index', () {
      final data = ActiveNavData(
        journey: walkRideWalk(currentSegmentIndex: 1),
        stages: stages,
        now: DateTime(2025, 1, 1, 10, 0),
      );

      final steps = data.timeline;
      expect(steps.map((s) => s.state).toList(), [
        NavStepState.completed, // walk to the stage is behind the traveller
        NavStepState.current, // boarding the matatu
        NavStepState.upcoming, // the ride ends later
        NavStepState.upcoming, // final walk
      ]);
      expect(steps[0].title, 'Walk to Kariobangi Stage');
      expect(steps[1].title, 'Route 46');
      expect(steps[3].title, 'Walk to your destination');
    });

    test('when the journey is complete every step is completed', () {
      final data = ActiveNavData(
        journey: walkRideWalk(currentSegmentIndex: 3),
        stages: stages,
      );
      expect(data.timeline.every((s) => s.state == NavStepState.completed),
          isTrue);
    });

    testWidgets('collapsed sheet shows the current step and the next two',
        (tester) async {
      final data = ActiveNavData(
        journey: walkRideWalk(currentSegmentIndex: 1),
        stages: stages,
        now: DateTime(2025, 1, 1, 10, 0),
      );

      await tester.pumpWidget(panel(data, expanded: false));

      final rows =
          tester.widgetList<NavTimelineRow>(find.byType(NavTimelineRow));
      expect(rows.length, 3);
      expect(rows.map((r) => r.step.state), [
        NavStepState.current,
        NavStepState.upcoming,
        NavStepState.upcoming,
      ]);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('Walk to Kariobangi Stage'), findsNothing,
          reason: 'completed steps only appear once the sheet is expanded');
    });

    testWidgets('expanded sheet reveals completed steps and the check mark',
        (tester) async {
      final data = ActiveNavData(
        journey: walkRideWalk(currentSegmentIndex: 1),
        stages: stages,
      );

      await tester.pumpWidget(panel(data, expanded: true));

      final rows = tester
          .widgetList<NavTimelineRow>(find.byType(NavTimelineRow))
          .toList();
      expect(rows.first.step.state, NavStepState.completed);
      expect(find.text('Walk to Kariobangi Stage'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NavTimelineRow),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    });

    testWidgets('upcoming copy stays at full contrast', (tester) async {
      final data = ActiveNavData(
        journey: walkRideWalk(currentSegmentIndex: 1),
        stages: stages,
      );

      await tester.pumpWidget(panel(data, expanded: false));

      final upcoming = tester
          .widgetList<NavTimelineRow>(find.byType(NavTimelineRow))
          .firstWhere((r) => r.step.state == NavStepState.upcoming);
      final text = tester.widget<Text>(find.descendant(
        of: find.byWidget(upcoming),
        matching: find.text(upcoming.step.title),
      ));
      expect(text.style?.color, NaviColors.textPrimaryLight);
      expect(text.style!.color!.a, 1.0);
    });

    testWidgets('secondary copy uses the dark-mode secondary colour',
        (tester) async {
      final data = ActiveNavData(
        journey: walkRideWalk(currentSegmentIndex: 1),
        stages: stages,
      );

      await tester.pumpWidget(panel(data, expanded: false, dark: true));

      final rows =
          tester.widgetList<NavTimelineRow>(find.byType(NavTimelineRow));
      final withSubtitle = rows.firstWhere((r) => r.step.subtitle != null);
      final subtitle = tester.widget<Text>(find.descendant(
        of: find.byWidget(withSubtitle),
        matching: find.text(withSubtitle.step.subtitle!),
      ));
      expect(subtitle.style?.color, NaviColors.textSecondaryDark);
    });

    testWidgets('expanded ride reveals the stop count and its stop names',
        (tester) async {
      final data = ActiveNavData(
        journey: walkRideWalk(currentSegmentIndex: 1),
        stages: stages,
        extras: const PreTripExtras(
          stopCounts: {1: 2},
          stopNames: {
            1: ['Kariobangi', 'Makadara'],
          },
        ),
      );

      await tester.pumpWidget(panel(data, expanded: true));
      expect(find.text('2 stops'), findsOneWidget);

      await tester.tap(find.text('2 stops'));
      await tester.pumpAndSettle();
      expect(find.text('Kariobangi · Makadara'), findsOneWidget);
    });
  });

  group('approximate route', () {
    testWidgets('an approximate walking leg shows the small note',
        (tester) async {
      final journey = ActiveJourney(segments: [
        RouteSegment.walk(
          label: 'Walk to Kariobangi Stage',
          coordinates: [origin, boarding],
          startPoint: origin,
          endPoint: boarding,
          approximate: true,
        ),
        RouteSegment.matatu(
          label: 'Ride Route 46 to Makadara',
          coordinates: [boarding, alighting],
          routeNumber: '46',
          fromStageId: 'kariobangi',
          toStageId: 'makadara',
          startPoint: boarding,
          endPoint: alighting,
        ),
      ]);

      await pumpOverlay(tester, journey: journey);

      expect(find.text('Approximate route'), findsOneWidget);
    });

    testWidgets('a fully road-resolved journey shows no note', (tester) async {
      await pumpOverlay(tester);
      expect(find.text('Approximate route'), findsNothing);
    });
  });

  group('fare row', () {
    testWidgets('shows the calculator fare between timeline and End Journey',
        (tester) async {
      await pumpOverlay(
        tester,
        journey: walkRideWalkWithFare(80),
        size: const Size(412, 915),
      );

      expect(find.byKey(const Key('activeNavFareRow')), findsOneWidget);
      expect(find.text('Fare KSh 80'), findsOneWidget);

      final timeline = tester.getRect(find.byType(NavTimelineCard));
      final fareRow = tester.getRect(find.byKey(const Key('activeNavFareRow')));
      final endButton =
          tester.getRect(find.widgetWithText(FilledButton, 'End Journey'));
      expect(fareRow.top, greaterThanOrEqualTo(timeline.bottom));
      expect(endButton.top, greaterThanOrEqualTo(fareRow.bottom));
      expect(endButton.top - fareRow.bottom, lessThanOrEqualTo(16),
          reason: 'End Journey sits directly under the fare row');
    });

    testWidgets('hidden when the fare is unknown', (tester) async {
      await pumpOverlay(tester);

      expect(find.byKey(const Key('activeNavFareRow')), findsNothing);
      expect(find.textContaining('Fare KSh'), findsNothing);
    });

    test('a known fare adds just enough height to the initial sheet', () {
      const size = Size(400, 900);
      final without = NavigationOverlay.initialExtentFor(size);
      final withFare = NavigationOverlay.initialExtentFor(size, hasFare: true);
      expect(withFare - without,
          closeTo(NavigationOverlay.fareRowPx / 900, 0.001));
    });
  });

  group('actions', () {
    testWidgets('End Journey asks for confirmation first', (tester) async {
      var ended = false;
      await pumpOverlay(tester, onEndTrip: () => ended = true);

      await tester.tap(find.widgetWithText(FilledButton, 'End Journey'));
      await tester.pumpAndSettle();
      expect(find.text('End this journey?'), findsOneWidget);
      expect(ended, isFalse);

      await tester.tap(find.widgetWithText(TextButton, 'Keep going'));
      await tester.pumpAndSettle();
      expect(ended, isFalse);

      await tester.tap(find.widgetWithText(FilledButton, 'End Journey'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'End Journey'),
      ));
      await tester.pumpAndSettle();
      expect(ended, isTrue);
    });

    testWidgets('dark mode keeps the banner ink and uses dark surfaces',
        (tester) async {
      await pumpOverlay(tester, dark: true);

      final bannerBox = tester.widget<DecoratedBox>(find
          .descendant(
            of: find.byType(NavInstructionBanner),
            matching: find.byType(DecoratedBox),
          )
          .first);
      expect((bannerBox.decoration as BoxDecoration).color,
          const Color(0xFF12161C));

      final panel =
          tester.widget<Material>(find.byKey(const Key('activeNavPanel')));
      expect(panel.color, NaviColors.surfaceDark);
    });
  });
}
