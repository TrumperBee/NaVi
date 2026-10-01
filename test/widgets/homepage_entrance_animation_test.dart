import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/widgets/homepage_entrance_animation.dart';

void main() {
  Widget harness({required bool reduceMotion}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          disableAnimations: reduceMotion,
        ),
        child: Scaffold(
          body: HomepageEntranceAnimation(
            builder: (_, mapAnim, topAnim, sheetAnim) {
              return Stack(
                children: [
                  FadeTransition(
                    key: const Key('mapFade'),
                    opacity: mapAnim,
                    child: const Text('map'),
                  ),
                  SlideTransition(
                    key: const Key('topSlide'),
                    position:
                        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
                            .animate(topAnim),
                    child: FadeTransition(
                      key: const Key('topFade'),
                      opacity: topAnim,
                      child: const Text('top'),
                    ),
                  ),
                  SlideTransition(
                    key: const Key('sheetSlide'),
                    position:
                        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                            .animate(sheetAnim),
                    child: FadeTransition(
                      key: const Key('sheetFade'),
                      opacity: sheetAnim,
                      child: const Text('sheet'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double mapOpacity(WidgetTester tester) =>
      tester.widget<FadeTransition>(find.byKey(const Key('mapFade'))).opacity
          .value;
  Offset topOffset(WidgetTester tester) => tester
      .widget<SlideTransition>(find.byKey(const Key('topSlide')))
      .position
      .value;
  Offset sheetOffset(WidgetTester tester) => tester
      .widget<SlideTransition>(find.byKey(const Key('sheetSlide')))
      .position
      .value;
  double sheetOpacity(WidgetTester tester) =>
      tester.widget<FadeTransition>(find.byKey(const Key('sheetFade'))).opacity
          .value;

  testWidgets('plays one staggered entrance and settles within the budget',
      (tester) async {
    await tester.pumpWidget(harness(reduceMotion: false));
    await tester.pump();

    // t = 100ms: the map is mid-fade but the top bar (starts at ~102ms) and
    // the sheet (starts at ~252ms) have not moved yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(mapOpacity(tester), greaterThan(0.0));
    expect(mapOpacity(tester), lessThan(1.0));
    expect(topOffset(tester), const Offset(0, -1),
        reason: 'search/QuickGo must start after the map begins');
    expect(sheetOffset(tester), const Offset(0, 1),
        reason: 'sheet must wait until the top region has started');

    // t ≈ 600ms: everything has reached its final state (sheet ends ~552ms).
    await tester.pump(const Duration(milliseconds: 500));
    expect(mapOpacity(tester), 1.0);
    expect(topOffset(tester), Offset.zero);
    expect(sheetOffset(tester), Offset.zero);
    expect(sheetOpacity(tester), 1.0);

    // Nothing keeps animating after the budget.
    await tester.pump(const Duration(milliseconds: 50));
    expect(mapOpacity(tester), 1.0);
    expect(topOffset(tester), Offset.zero);
    expect(sheetOffset(tester), Offset.zero);

    await tester.pumpAndSettle();
  });

  testWidgets('renders the final frame immediately when reduced motion is on',
      (tester) async {
    await tester.pumpWidget(harness(reduceMotion: true));
    await tester.pump();

    expect(mapOpacity(tester), 1.0,
        reason: 'no entrance animation under disableAnimations');
    expect(topOffset(tester), Offset.zero);
    expect(sheetOffset(tester), Offset.zero);
    expect(sheetOpacity(tester), 1.0);

    await tester.pumpAndSettle();
  });

  testWidgets('plays once per state creation, not on every rebuild',
      (tester) async {
    await tester.pumpWidget(harness(reduceMotion: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(mapOpacity(tester), 1.0);

    // A rebuild in place reuses the same State → must NOT replay.
    await tester.pumpWidget(harness(reduceMotion: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(mapOpacity(tester), 1.0,
        reason: 'a plain rebuild must not re-run the entrance');

    // A fresh State (unmount then remount) replays from the start.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(harness(reduceMotion: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(mapOpacity(tester), greaterThan(0.0));
    expect(mapOpacity(tester), lessThan(1.0),
        reason: 'a new State replays the entrance');

    await tester.pump(const Duration(milliseconds: 500));
  });
}