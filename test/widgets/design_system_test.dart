import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi_app/core/theme.dart';
import 'package:navi_app/design/navi_colors.dart';
import 'package:navi_app/design/navi_spacing.dart';
import 'package:navi_app/design/navi_typography.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/widgets/hero_go_card.dart';
import 'package:navi_app/widgets/nearby_stages_list.dart';
import 'package:navi_app/widgets/quick_go_row.dart';
import 'package:navi_app/widgets/route_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _wrapDark(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: child),
    );

void main() {
  group('RouteBadge', () {
    testWidgets('renders route number with ink text on psv yellow', (tester) async {
      await tester.pumpWidget(_wrap(const RouteBadge(routeNumber: '34')));

      expect(find.text('34'), findsOneWidget);

      final text = tester.widget<Text>(find.text('34'));
      expect(text.style?.color, NaviColors.ink);
      expect(text.style?.fontWeight, FontWeight.w700);

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(RouteBadge), matching: find.byType(Container)),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, NaviColors.psvYellow);
      expect((decoration.borderRadius! as BorderRadius).topLeft.x, NaviRadius.badge);
    });

    testWidgets('badge geometry is rectangular, not a pill', (tester) async {
      await tester.pumpWidget(_wrap(const RouteBadge(routeNumber: '34')));
      final size = tester.getSize(find.byType(RouteBadge));
      const radius = NaviRadius.badge;

      expect(radius, lessThan(size.height / 2),
          reason: 'a 4dp radius must be less than half the height, '
              'otherwise the badge collapses into a pill');
    });
  });

  group('RouteBadgeRow', () {
    testWidgets('lays out multiple badges with 6dp gap', (tester) async {
      await tester.pumpWidget(_wrap(const RouteBadgeRow(routeNumbers: ['34', '125', '8'])));

      expect(find.byType(RouteBadge), findsNWidgets(3));
      expect(find.text('34'), findsOneWidget);
      expect(find.text('125'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

      final badges = tester.widgetList<RouteBadge>(find.byType(RouteBadge)).toList();
      expect(badges.map((b) => b.routeNumber), ['34', '125', '8']);

      final first = tester.getTopLeft(find.byType(RouteBadge).first);
      final second = tester.getTopLeft(find.byType(RouteBadge).at(1));
      expect(second.dx - (first.dx + tester.getSize(find.byType(RouteBadge).first).width),
          NaviSpacing.badgeGap);
    });
  });

  group('HeroGoCard', () {
    testWidgets('renders stage, labels, and route badges on ink background', (tester) async {
      await tester.pumpWidget(_wrap(HeroGoCard(
        stageName: 'Kilimani',
        distanceLabel: '730m away',
        walkTimeLabel: '6 min walk',
        routeNumbers: const ['34', '125'],
        onTap: () {},
      )));

      expect(find.text('Kilimani'), findsOneWidget);
      expect(find.text('730m away'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('min walk'), findsOneWidget);
      expect(find.byType(RouteBadge), findsNWidgets(2));
      // No label eyebrow unless explicitly requested.
      expect(find.text('Nearest stage'), findsNothing);

      final material = tester.widget<Material>(
        find.descendant(of: find.byType(HeroGoCard), matching: find.byType(Material)).first,
      );
      expect(material.color, NaviColors.ink);

      final title = tester.widget<Text>(find.text('Kilimani'));
      expect(title.style?.color, Colors.white);
      expect(title.style?.fontSize, NaviType.title.fontSize);
      expect(title.style?.fontWeight, FontWeight.w700);

      final numeral = tester.widget<Text>(find.text('6'));
      expect(numeral.style?.color, Colors.white);
      expect(numeral.style?.fontSize, NaviType.heroNumeral.fontSize);
      expect(numeral.style?.fontFamily, NaviType.displayFontFamily);
    });

    testWidgets('hero numeral is larger than surrounding text', (tester) async {
      await tester.pumpWidget(_wrap(HeroGoCard(
        stageName: 'Kilimani',
        distanceLabel: '730m',
        walkTimeLabel: '12 min walk',
        routeNumbers: const ['34'],
        onTap: () {},
      )));

      final numeralSize = tester.widget<Text>(find.text('12')).style?.fontSize ?? 0;
      final captionSize = tester.widget<Text>(find.text('min walk')).style?.fontSize ?? 0;
      expect(numeralSize, greaterThan(captionSize));
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(HeroGoCard(
        stageName: 'Kilimani',
        distanceLabel: '730m',
        walkTimeLabel: '6 min walk',
        routeNumbers: const ['34'],
        onTap: () => tapped = true,
      )));

      await tester.tap(find.text('Kilimani'));
      expect(tapped, isTrue);
    });

    testWidgets('renders the nearest-stage label eyebrow in transit green', (tester) async {
      await tester.pumpWidget(_wrap(HeroGoCard(
        labelTitle: 'Nearest stage',
        stageName: 'Kilimani',
        distanceLabel: '730m away',
        walkTimeLabel: '6 min walk',
        routeNumbers: const ['34'],
        onTap: () {},
      )));

      expect(find.text('Nearest stage'), findsOneWidget);
      expect(find.byIcon(Icons.near_me), findsOneWidget);

      final label = tester.widget<Text>(find.text('Nearest stage'));
      expect(label.style?.color, NaviColors.transitGreen);

      // The eyebrow sits above the stage name, not below it.
      final labelBottom = tester.getBottomLeft(find.text('Nearest stage')).dy;
      final titleTop = tester.getTopLeft(find.text('Kilimani')).dy;
      expect(labelBottom, lessThan(titleTop));
    });

    testWidgets('handles a walk time label without a leading numeral', (tester) async {
      await tester.pumpWidget(_wrap(HeroGoCard(
        stageName: 'Kilimani',
        distanceLabel: '730m',
        walkTimeLabel: 'Arriving',
        routeNumbers: const ['34'],
        onTap: () {},
      )));

      expect(find.text('Arriving'), findsOneWidget);
      expect(find.text('6'), findsNothing);
    });
  });

  group('HeroGoCardPlaceholder', () {
    testWidgets('shows message and triggers onEnableLocation', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        HeroGoCardPlaceholder(onEnableLocation: () => tapped = true),
      ));

      expect(find.text('Enable location to see your nearest stage'),
          findsOneWidget);

      await tester.tap(find.text('Enable Location'));
      expect(tapped, isTrue);
    });
  });

  group('HeroGoCardLoading', () {
    testWidgets('renders a skeletal shimmer on the ink hero card',
        (tester) async {
      await tester.pumpWidget(_wrap(const HeroGoCardLoading()));

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(HeroGoCardLoading),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, NaviColors.ink);
      expect(find.byType(FractionallySizedBox), findsNWidgets(3));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Getting your location…'), findsOneWidget,
          reason: 'the loading card must name which wait is happening');
    });

    testWidgets('names the stage-lookup phase after GPS resolves',
        (tester) async {
      await tester.pumpWidget(_wrap(const HeroGoCardLoading(
        phase: HeroGoLoadPhase.findingStages,
      )));

      expect(find.text('Finding nearby stages…'), findsOneWidget);
    });

    testWidgets('reserves the final hero card height so the sheet does not jump',
        (tester) async {
      const cardOf = HeroGoCard(
        stageName: 'Kilimani',
        distanceLabel: '730 m away',
        walkTimeLabel: '6 min walk',
        routeNumbers: ['34', '125'],
      );
      await tester.pumpWidget(_wrap(const HeroGoCardLoading(
        stageName: 'Kilimani',
        distanceLabel: '730 m away',
        walkTimeLabel: '6 min walk',
        routeNumbers: ['34', '125'],
      )));
      final loadingSize = tester.getSize(find.byType(HeroGoCardLoading));

      await tester.pumpWidget(_wrap(cardOf));
      final cardSize = tester.getSize(find.byType(HeroGoCard));

      expect((loadingSize.height - cardSize.height).abs(), lessThanOrEqualTo(1),
        reason:
            'the skeleton is an approximation; within a pixel keeps the '
            'fraction-driven sheet from visibly jumping');
      expect((loadingSize.width - cardSize.width).abs(), lessThanOrEqualTo(1));
    });
  });

  group('HeroGoCardEmptyState', () {
    testWidgets('explains coverage informatively without an error tone',
        (tester) async {
      await tester.pumpWidget(_wrap(const HeroGoCardEmptyState()));

      expect(find.text('No stages nearby yet'), findsOneWidget);
      expect(find.textContaining('Nairobi metro'), findsOneWidget);

      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(HeroGoCardEmptyState),
              matching: find.byWidgetPredicate(
                (w) => w is Container && w.decoration != null,
              ),
            )
            .first,
      );
      final deco = card.decoration! as BoxDecoration;
      expect(deco.color, NaviColors.canvasLight);
      expect(deco.border!.top.color, NaviColors.divider);
    });
  });

  group('HeroGoCardLocationTimeout', () {
    testWidgets('explains the stalled fix and offers a manual retry',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(_wrap(HeroGoCardLocationTimeout(
        onRetry: () => retried = true,
      )));

      expect(find.text('Still finding your location'), findsOneWidget);
      expect(find.textContaining('Check your GPS signal'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });

    testWidgets('keeps the ink hero background', (tester) async {
      await tester.pumpWidget(_wrap(const HeroGoCardLocationTimeout()));

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(HeroGoCardLocationTimeout),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, NaviColors.ink);
    });
  });

  group('QuickGoRow', () {
    testWidgets('renders quiet chips with transitGreen icons', (tester) async {
      const home = SavedDestination(
        id: 'home',
        label: 'Home',
        latitude: -1.2833,
        longitude: 36.8167,
        type: SavedDestinationType.home,
      );
      await tester.pumpWidget(_wrap(QuickGoRow(
        destinations: const [home],
        onTap: _noopOnDestination,
        onAddWork: () {},
      )));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Add Work'), findsOneWidget);

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(QuickGoRow),
          matching: find.byIcon(Icons.home),
        ),
      );
      expect(icon.color, NaviColors.transitGreen);

      final chip = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(QuickGoRow),
              matching: find.byWidgetPredicate(
                (w) => w is Container && w.decoration != null,
              ),
            )
            .first,
      );
      final deco = chip.decoration! as BoxDecoration;
      expect(deco.color, NaviColors.canvasLight);
      expect(deco.border!.top.color, NaviColors.divider);
      expect(deco.border!.top.width, 1);
    });

    testWidgets('chips expose a minimum 44x44 touch target', (tester) async {
      const home = SavedDestination(
        id: 'home',
        label: 'Home',
        latitude: -1.2833,
        longitude: 36.8167,
        type: SavedDestinationType.home,
      );
      await tester.pumpWidget(_wrap(const QuickGoRow(
        destinations: [home],
        onTap: _noopOnDestination,
      )));

      expect(QuickGoRow.rowHeight, greaterThanOrEqualTo(44));

      final ink = tester.widget<InkWell>(
        find
            .descendant(
              of: find.byType(QuickGoRow),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(tester.getSize(find.byWidget(ink)).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(find.byWidget(ink)).width, greaterThanOrEqualTo(44));
    });

    testWidgets('renders nothing when there are no destinations or add chips',
        (tester) async {
      await tester.pumpWidget(_wrap(const QuickGoRow(
        destinations: [],
        onTap: _noopOnDestination,
        onAddHome: null,
        onAddWork: null,
        onAddCampus: null,
      )));

      expect(find.byType(Container), findsNothing);
    });
  });

  group('NearbyStagesList', () {
    testWidgets('renders restyled rows with RouteBadge and navi tokens',
        (tester) async {
      final stage = StageModel(
        id: 's1',
        name: 'Kilimani',
        lat: -1.29,
        lng: 36.78,
        corridor: 'Argwings Kodhek',
        routes: ['34', '125'],
      );
      await tester.pumpWidget(_wrap(NearbyStagesList(
        stages: [
          NearbyStageEntry(stage: stage, distanceMeters: 730),
        ],
        onStageTap: _noopOnStage,
      )));

      expect(find.text('Kilimani'), findsOneWidget);
      expect(find.text('Argwings Kodhek · 730 m away'), findsOneWidget);
      expect(find.byType(RouteBadge), findsNWidgets(2));

      final title = tester.widget<Text>(find.text('Kilimani'));
      expect(title.style?.fontSize, NaviType.cardTitle.fontSize);
      expect(title.style?.color, NaviColors.ink);

      final subtitle = tester.widget<Text>(find.text('Argwings Kodhek · 730 m away'));
      expect(subtitle.style?.color, NaviColors.muted);
    });

    testWidgets('hides distance suffix when distance is unknown', (tester) async {
      final stage = StageModel(
        id: 's2',
        name: 'Town',
        lat: -1.284,
        lng: 36.82,
        corridor: 'Moi Avenue',
        routes: ['8'],
      );
      await tester.pumpWidget(_wrap(NearbyStagesList(
        stages: [NearbyStageEntry(stage: stage)],
        onStageTap: _noopOnStage,
      )));

      expect(find.text('Moi Avenue'), findsOneWidget);
      expect(find.textContaining('away'), findsNothing);
    });

    testWidgets('invokes onStageTap when a row is tapped', (tester) async {
      final stage = StageModel(
        id: 's1',
        name: 'Kilimani',
        lat: -1.29,
        lng: 36.78,
        corridor: 'Argwings Kodhek',
        routes: ['34'],
      );
      StageModel? tapped;
      await tester.pumpWidget(_wrap(NearbyStagesList(
        stages: [NearbyStageEntry(stage: stage)],
        onStageTap: (s) => tapped = s,
      )));

      await tester.tap(find.text('Kilimani'));
      expect(tapped?.name, 'Kilimani');
    });
  });

  group('Accessibility checks', () {
    double luminance(Color color) {
      double linear(double channel) {
        return channel <= 0.04045
            ? channel / 12.92
            : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
      }

      final r = linear(color.r);
      final g = linear(color.g);
      final b = linear(color.b);
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    test('RouteBadge ink-on-psv-yellow contrast meets WCAG AA (>=4.5:1)',
        () {
      final ink = luminance(NaviColors.ink);
      final yellow = luminance(NaviColors.psvYellow);
      final lighter = math.max(ink, yellow);
      final darker = math.min(ink, yellow);
      final ratio = (lighter + 0.05) / (darker + 0.05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('empty-state muted text on canvas still meets WCAG AA', () {
      final canvas = luminance(NaviColors.canvasLight);
      final muted = luminance(NaviColors.muted);
      final lighter = math.max(canvas, muted);
      final darker = math.min(canvas, muted);
      final ratio = (lighter + 0.05) / (darker + 0.05);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'secondary copy must remain legible at >=4.5:1');
    });

    testWidgets(
        'HeroGoCard does not overflow at the largest system text scale',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(3.0),
          ),
          child: Scaffold(
            body: HeroGoCard(
              stageName: 'Roysambu Bus Station Corridor Four',
              distanceLabel: '2.4 km away',
              walkTimeLabel: '32 min walk',
              routeNumbers: ['34', '125', '8', '45'],
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Roysambu Bus Station Corridor Four'), findsOneWidget);
      expect(find.byType(FittedBox), findsWidgets,
          reason: 'long labels must be allowed to scale down');
    });
  });

  group('Dark mode', () {
    test('token helpers select dark variants when isDark is true', () {
      expect(NaviColors.canvas(true), NaviColors.canvasDark);
      expect(NaviColors.canvas(false), NaviColors.canvasLight);
      expect(NaviColors.surface(true), NaviColors.surfaceDark);
      expect(NaviColors.surface(false), NaviColors.surfaceLight);
      expect(NaviColors.textPrimary(true), NaviColors.textPrimaryDark);
      expect(NaviColors.textPrimary(false), NaviColors.textPrimaryLight);
      expect(NaviColors.textSecondary(true), NaviColors.textSecondaryDark);
      expect(NaviColors.textSecondary(false), NaviColors.textSecondaryLight);
      expect(NaviColors.dividerC(true), NaviColors.dividerDark);
      expect(NaviColors.dividerC(false), NaviColors.divider);
    });

    test('brand tokens are identical in both themes', () {
      expect(NaviColors.ink, const Color(0xFF12161C));
      expect(NaviColors.psvYellow, const Color(0xFFFFC627));
      expect(NaviColors.transitGreen, const Color(0xFF00875A));
      expect(NaviColors.signalBlue, const Color(0xFF1A73E8));
      expect(NaviColors.alertAmber, const Color(0xFFF59E0B));
    });

    test('AppTheme.dark scaffold and surfaces use dark tokens', () {
      final dark = AppTheme.darkTheme;
      expect(dark.scaffoldBackgroundColor, NaviColors.canvasDark);
      expect(dark.canvasColor, NaviColors.canvasDark);
      expect(dark.cardColor, NaviColors.surfaceDark);
      expect(dark.dividerColor, NaviColors.dividerDark);
      expect(dark.colorScheme.surface, NaviColors.surfaceDark);

      final light = AppTheme.lightTheme;
      expect(light.scaffoldBackgroundColor, NaviColors.canvasLight);
      expect(light.canvasColor, NaviColors.canvasLight);
      expect(light.cardColor, NaviColors.surfaceLight);
      expect(light.colorScheme.surface, NaviColors.surfaceLight);
    });

    testWidgets('HeroGoCardEmptyState renders dark canvas with light text',
        (tester) async {
      await tester.pumpWidget(_wrapDark(const HeroGoCardEmptyState()));

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(HeroGoCardEmptyState),
              matching: find.byWidgetPredicate(
                (w) => w is Container && w.decoration != null,
              ),
            )
            .first,
      );
      final deco = container.decoration! as BoxDecoration;
      expect(deco.color, NaviColors.canvasDark);
      expect(deco.border!.top.color, NaviColors.dividerDark);

      final title = tester.widget<Text>(find.text('No stages nearby yet'));
      expect(title.style?.color, NaviColors.textPrimaryDark);
    });

    testWidgets('QuickGoRow chips use dark canvas and divider',
        (tester) async {
      const home = SavedDestination(
        id: 'home',
        label: 'Home',
        latitude: -1.2833,
        longitude: 36.8167,
        type: SavedDestinationType.home,
      );
      await tester.pumpWidget(_wrapDark(QuickGoRow(
        destinations: const [home],
        onTap: _noopOnDestination,
      )));

      final chip = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(QuickGoRow),
              matching: find.byWidgetPredicate(
                (w) => w is Container && w.decoration != null,
              ),
            )
            .first,
      );
      final deco = chip.decoration! as BoxDecoration;
      expect(deco.color, NaviColors.canvasDark);
      expect(deco.border!.top.color, NaviColors.dividerDark);

      final label = tester.widget<Text>(find.text('Home'));
      expect(label.style?.color, NaviColors.textPrimaryDark);
    });
  });
}

void _noopOnDestination(SavedDestination _) {}

void _noopOnStage(StageModel _) {}