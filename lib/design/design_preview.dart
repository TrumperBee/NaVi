import 'package:flutter/material.dart';

import 'navi_colors.dart';
import 'navi_typography.dart';
import '../widgets/hero_go_card.dart';
import '../widgets/route_badge.dart';

/// Throwaway design-system preview.
///
/// Run on its own entrypoint (bypasses the app's `main.dart`) to visually
/// verify the Phase 1 tokens and components:
///
///     flutter run -t lib/design/design_preview.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaviType.ensureLoaded();
  runApp(const _DesignPreviewApp());
}

class _DesignPreviewApp extends StatelessWidget {
  const _DesignPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NaVi Design Preview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: NaviColors.canvasLight,
        colorScheme: ColorScheme.fromSeed(seedColor: NaviColors.transitGreen),
      ),
      home: const _PreviewScreen(),
    );
  }
}

class _PreviewScreen extends StatelessWidget {
  const _PreviewScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NaVi design preview', style: NaviType.title),
              const SizedBox(height: 4),
              const Text(
                'Phase 1: tokens + signature components',
                style: NaviType.caption,
              ),
              const SizedBox(height: 32),
              const Text('RouteBadge (rectangular, 4dp radius)', style: NaviType.cardTitle),
              const SizedBox(height: 12),
              const RouteBadge(routeNumber: '34'),
              const SizedBox(height: 12),
              const Text('RouteBadgeRow (wrapping, 6dp gap)', style: NaviType.cardTitle),
              const SizedBox(height: 12),
              const RouteBadgeRow(routeNumbers: ['34', '125', '8']),
              const SizedBox(height: 32),
              const Text('HeroGoCard (only dark element)', style: NaviType.cardTitle),
              const SizedBox(height: 12),
              HeroGoCard(
                stageName: 'Kilimani',
                distanceLabel: '730m away',
                walkTimeLabel: '6 min walk',
                routeNumbers: const ['34', '125', '8'],
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}