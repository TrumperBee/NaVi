import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/widgets/maneuver_transition.dart';

void main() {
  Widget harness({required int stepIndex, required bool reduceMotion}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          disableAnimations: reduceMotion,
        ),
        child: Scaffold(
          body: ManeuverTransition(
            stepIndex: stepIndex,
            child: Text(stepIndex == 0 ? 'Walk' : 'Ride'),
          ),
        ),
      ),
    );
  }

  group('ManeuverTransition', () {
    testWidgets('slides+fades between steps when the index changes',
        (tester) async {
      await tester.pumpWidget(harness(stepIndex: 0, reduceMotion: false));
      expect(find.text('Walk'), findsOneWidget);
      expect(find.text('Ride'), findsNothing);

      await tester.pumpWidget(harness(stepIndex: 1, reduceMotion: false));
      await tester.pump();

      // The one deliberate animated moment: outgoing is still fading out while
      // the incoming is fading in.
      expect(find.text('Walk'), findsOneWidget,
          reason: 'outgoing step should remain mid-transition');
      expect(find.text('Ride'), findsOneWidget,
          reason: 'incoming step should be animating in');

      await tester.pump(kManeuverTransitionDuration +
          const Duration(milliseconds: 100));
      expect(find.text('Walk'), findsNothing,
          reason: 'outgoing step must be gone after the transition');
      expect(find.text('Ride'), findsOneWidget);
    });

    testWidgets('skips the transition entirely under reduced motion',
        (tester) async {
      await tester.pumpWidget(harness(stepIndex: 0, reduceMotion: true));
      expect(find.text('Walk'), findsOneWidget);

      await tester.pumpWidget(harness(stepIndex: 1, reduceMotion: true));
      await tester.pump();

      expect(find.text('Walk'), findsNothing,
          reason: 'reduced motion swaps the step instantly');
      expect(find.text('Ride'), findsOneWidget,
          reason: 'content still updates when animations are off');
    });

    testWidgets('does not animate when the index is unchanged',
        (tester) async {
      await tester.pumpWidget(harness(stepIndex: 0, reduceMotion: false));
      await tester.pumpWidget(harness(stepIndex: 0, reduceMotion: false));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Walk'), findsOneWidget);
      expect(find.text('Ride'), findsNothing);
    });
  });

  group('TweenMetric', () {
    Future<void> pumpMetric(
      WidgetTester tester,
      double value, {
      required bool reduceMotion,
      List<double>? samples,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 800),
              disableAnimations: reduceMotion,
            ),
            child: TweenMetric(
              value: value,
              builder: (context, current) {
                samples?.add(current);
                return Text(current.toStringAsFixed(0));
              },
            ),
          ),
        ),
      );
    }

    testWidgets('eases toward the new value instead of snapping',
        (tester) async {
      final samples = <double>[];
      await pumpMetric(tester, 100, reduceMotion: false, samples: samples);
      await tester.pump();
      expect(find.text('100'), findsOneWidget);

      await pumpMetric(tester, 120, reduceMotion: false, samples: samples);
      await tester.pump(const Duration(milliseconds: 150));
      final mid = samples.last;
      expect(mid, greaterThan(100.0));
      expect(mid, lessThan(120.0));

      await tester.pump(kManeuverTransitionDuration +
          const Duration(milliseconds: 50));
      expect(find.text('120'), findsOneWidget,
          reason: 'the metric settles on the new value');
    });

    testWidgets('renders the target value immediately under reduced motion',
        (tester) async {
      await pumpMetric(tester, 100, reduceMotion: true);
      await tester.pump();
      expect(find.text('100'), findsOneWidget);

      await pumpMetric(tester, 120, reduceMotion: true);
      await tester.pump();
      expect(find.text('120'), findsOneWidget,
          reason: 'no count-up animation text at any intermediate step');
    });
  });
}