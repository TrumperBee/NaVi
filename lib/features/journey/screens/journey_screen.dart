import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:navi_app/core/constants.dart';
import 'package:navi_app/providers/journey_provider.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';
import 'package:navi_app/features/journey/widgets/journey_timeline.dart';
import 'package:navi_app/features/journey/widgets/progress_indicators.dart';

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<JourneyProvider>(
      builder: (context, journey, child) {
        return SafeArea(
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                _JourneyHeader(journey: journey),
                _AssistantCard(journey: journey),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PhaseContent(journey: journey),
                        const SizedBox(height: 24),
                        _ProgressSection(journey: journey),
                        const SizedBox(height: 24),
                        _TimelineSection(journey: journey),
                      ],
                    ),
                  ),
                ),
                _JourneyBottomBar(journey: journey),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _JourneyHeader extends StatelessWidget {
  final JourneyProvider journey;
  const _JourneyHeader({required this.journey});

  @override
  Widget build(BuildContext context) {
    final largeText = journey.largeText;
    final nairobiGreen = AppConstants.nairobiGreen;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: journey.currentPhase == JourneyPhase.journeyComplete
                ? () {
                    journey.resetJourney();
                    journey.closeJourneyScreen();
                  }
                : () => journey.closeJourneyScreen(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  journey.getPhaseLabel(),
                  style: TextStyle(
                    fontSize: largeText ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: nairobiGreen,
                  ),
                ),
                if (journey.currentPhase != JourneyPhase.journeyComplete &&
                    journey.currentPhase != JourneyPhase.beforeTravel)
                  Text(
                    '${journey.routeNumber} · ${journey.fromStageName} → ${journey.toStageName}',
                    style: TextStyle(
                      fontSize: largeText ? 14 : 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          if (journey.isActive)
            GestureDetector(
              onTap: () => journey.togglePause(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: journey.isPaused
                      ? nairobiGreen.withValues(alpha: 0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  journey.isPaused ? Icons.play_arrow : Icons.pause,
                  color: journey.isPaused ? nairobiGreen : Colors.grey[700],
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  final JourneyProvider journey;
  const _AssistantCard({required this.journey});

  @override
  Widget build(BuildContext context) {
    final message = journey.lastAssistantMessage;
    if (message.isEmpty) return const SizedBox.shrink();

    final isCritical = journey.currentPhase == JourneyPhase.approachingDestination ||
        journey.currentPhase == JourneyPhase.alighting;
    final largeText = journey.largeText;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCritical
              ? [Colors.red.withValues(alpha: 0.08), Colors.orange.withValues(alpha: 0.05)]
              : [AppConstants.nairobiGreen.withValues(alpha: 0.08), Colors.green.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical
              ? Colors.red.withValues(alpha: 0.2)
              : AppConstants.nairobiGreen.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCritical ? Colors.red.withValues(alpha: 0.1) : AppConstants.nairobiGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: journey.highContrast
                ? Icon(
                    isCritical ? Icons.warning_amber_rounded : Icons.assistant,
                    color: isCritical ? Colors.red : AppConstants.nairobiGreen,
                    size: 20,
                  )
                : Text(
                    isCritical ? '⚠️' : '🤖',
                    style: const TextStyle(fontSize: 20),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: largeText ? 16 : 14,
                fontWeight: isCritical ? FontWeight.bold : FontWeight.w500,
                color: isCritical ? Colors.red[800] : Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseContent extends StatelessWidget {
  final JourneyProvider journey;
  const _PhaseContent({required this.journey});

  @override
  Widget build(BuildContext context) {
    switch (journey.currentPhase) {
      case JourneyPhase.beforeTravel:
        return _BeforeTravelContent(journey: journey);
      case JourneyPhase.walkingToStage:
        return _WalkingToStageContent(journey: journey);
      case JourneyPhase.waitingForMatatu:
        return _WaitingContent(journey: journey);
      case JourneyPhase.riding:
        return _RidingContent(journey: journey);
      case JourneyPhase.approachingDestination:
        return _ApproachingContent(journey: journey);
      case JourneyPhase.alighting:
        return _AlightingContent(journey: journey);
      case JourneyPhase.finalWalking:
        return _FinalWalkingContent(journey: journey);
      case JourneyPhase.journeyComplete:
        return _JourneyCompleteContent(journey: journey);
    }
  }
}

class _BeforeTravelContent extends StatelessWidget {
  final JourneyProvider journey;
  const _BeforeTravelContent({required this.journey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where to?',
          style: TextStyle(
            fontSize: journey.largeText ? 28 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Search for a destination to start your journey.',
          style: TextStyle(
            fontSize: journey.largeText ? 16 : 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _WalkingToStageContent extends StatelessWidget {
  final JourneyProvider journey;
  const _WalkingToStageContent({required this.journey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.directions_walk, color: Colors.blue, size: journey.largeText ? 32 : 28),
            const SizedBox(width: 8),
            Text(
              'Walk to ${journey.fromStageName}',
              style: TextStyle(
                fontSize: journey.largeText ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Head to ${journey.fromStageName} to board Route ${journey.routeNumber}.',
          style: TextStyle(
            fontSize: journey.largeText ? 16 : 14,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        _InfoRow(
          icon: Icons.directions_bus,
          label: 'Route ${journey.routeNumber}',
          largeText: journey.largeText,
        ),
        _InfoRow(
          icon: Icons.attach_money,
          label: 'KES ${journey.estimatedFare.toStringAsFixed(0)}',
          largeText: journey.largeText,
        ),
        _InfoRow(
          icon: Icons.timer,
          label: '~${journey.estimatedDuration} min',
          largeText: journey.largeText,
        ),
      ],
    );
  }
}

class _WaitingContent extends StatelessWidget {
  final JourneyProvider journey;
  const _WaitingContent({required this.journey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.nairobiGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('🚌', style: TextStyle(fontSize: journey.largeText ? 36 : 32)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Route ${journey.routeNumber}',
                    style: TextStyle(
                      fontSize: journey.largeText ? 24 : 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    journey.routeName.isNotEmpty ? journey.routeName : 'At ${journey.fromStageName}',
                    style: TextStyle(
                      fontSize: journey.largeText ? 16 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirm the route number with the conductor before boarding.',
                  style: TextStyle(
                    fontSize: journey.largeText ? 14 : 12,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RidingContent extends StatelessWidget {
  final JourneyProvider journey;
  const _RidingContent({required this.journey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.directions_bus, color: AppConstants.nairobiGreen, size: journey.largeText ? 32 : 28),
            const SizedBox(width: 8),
            Text(
              'En Route',
              style: TextStyle(
                fontSize: journey.largeText ? 22 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            _PhaseBadge(
              label: 'Route ${journey.routeNumber}',
              color: AppConstants.nairobiGreen,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _RidingStat(
                icon: Icons.location_on,
                value: journey.currentStageName,
                label: 'Current stop',
                largeText: journey.largeText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _RidingStat(
                icon: Icons.flag,
                value: journey.toStageName,
                label: 'Alight at',
                largeText: journey.largeText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ApproachingContent extends StatelessWidget {
  final JourneyProvider journey;
  const _ApproachingContent({required this.journey});

  @override
  Widget build(BuildContext context) {
    final fontSize = journey.largeText ? 24.0 : 20.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withValues(alpha: 0.08), Colors.orange.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            '⚠️',
            style: TextStyle(fontSize: journey.largeText ? 56 : 48),
          ),
          const SizedBox(height: 12),
          Text(
            'Prepare to Alight',
            style: TextStyle(
              fontSize: fontSize + 4,
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get ready to alight at ${journey.toStageName}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: journey.largeText ? 18 : 16,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${journey.remainingStops} stop${journey.remainingStops > 1 ? 's' : ''} away',
            style: TextStyle(
              fontSize: journey.largeText ? 16 : 14,
              fontWeight: FontWeight.w500,
              color: Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlightingContent extends StatelessWidget {
  final JourneyProvider journey;
  const _AlightingContent({required this.journey});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppConstants.nairobiGreen.withValues(alpha: 0.08), Colors.green.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppConstants.nairobiGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            '⬇️',
            style: TextStyle(fontSize: journey.largeText ? 56 : 48),
          ),
          const SizedBox(height: 12),
          Text(
            'Alight Here',
            style: TextStyle(
              fontSize: journey.largeText ? 24 : 22,
              fontWeight: FontWeight.bold,
              color: AppConstants.nairobiGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${journey.toStageName}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: journey.largeText ? 20 : 18,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalWalkingContent extends StatelessWidget {
  final JourneyProvider journey;
  const _FinalWalkingContent({required this.journey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.directions_walk, color: Colors.blue, size: journey.largeText ? 32 : 28),
            const SizedBox(width: 8),
            Text(
              'Walk to ${journey.destinationName}',
              style: TextStyle(
                fontSize: journey.largeText ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'You have alighted at ${journey.toStageName}. Walk to your final destination.',
          style: TextStyle(
            fontSize: journey.largeText ? 16 : 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

class _JourneyCompleteContent extends StatelessWidget {
  final JourneyProvider journey;
  const _JourneyCompleteContent({required this.journey});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppConstants.nairobiGreen.withValues(alpha: 0.1), Colors.green.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppConstants.nairobiGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            '✅',
            style: TextStyle(fontSize: journey.largeText ? 64 : 56),
          ),
          const SizedBox(height: 16),
          Text(
            'Journey Complete',
            style: TextStyle(
              fontSize: journey.largeText ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: AppConstants.nairobiGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Arrived at ${journey.destinationName}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: journey.largeText ? 18 : 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Route ${journey.routeNumber} · ${journey.elapsedTime.inMinutes} min',
            style: TextStyle(
              fontSize: journey.largeText ? 16 : 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final JourneyProvider journey;
  const _ProgressSection({required this.journey});

  @override
  Widget build(BuildContext context) {
    if (journey.currentPhase == JourneyPhase.beforeTravel ||
        journey.currentPhase == JourneyPhase.journeyComplete) {
      return const SizedBox.shrink();
    }

    final routeProgress = journey.getRouteProgress();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhaseBanner(
          label: journey.getPhaseLabel(),
          emoji: journey.getPhaseEmoji(),
          highContrast: journey.highContrast,
        ),
        const SizedBox(height: 16),
        if (journey.currentPhase == JourneyPhase.riding ||
            journey.currentPhase == JourneyPhase.approachingDestination) ...[
          JourneyProgressBar(
            progress: routeProgress.progressFraction,
            highContrast: journey.highContrast,
          ),
          const SizedBox(height: 12),
          StopChips(
            remainingStops: journey.remainingStops,
            completedStops: routeProgress.completedStops,
            totalStops: routeProgress.totalStops,
            largeText: journey.largeText,
          ),
          const SizedBox(height: 12),
          if (routeProgress.estimatedArrival != null)
            EstimatedArrivalCountdown(
              estimatedArrival: routeProgress.estimatedArrival,
              largeText: journey.largeText,
            ),
        ],
        if (journey.currentPhase == JourneyPhase.walkingToStage ||
            journey.currentPhase == JourneyPhase.finalWalking) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Journey time: ~${journey.estimatedDuration} min total',
                  style: TextStyle(
                    fontSize: journey.largeText ? 16 : 14,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TimelineSection extends StatelessWidget {
  final JourneyProvider journey;
  const _TimelineSection({required this.journey});

  @override
  Widget build(BuildContext context) {
    if (journey.currentPhase == JourneyPhase.beforeTravel) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Journey Timeline',
          style: TextStyle(
            fontSize: journey.largeText ? 18 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        JourneyTimeline(
          items: journey.timelineItems,
          highContrast: journey.highContrast,
        ),
      ],
    );
  }
}

class _JourneyBottomBar extends StatelessWidget {
  final JourneyProvider journey;
  const _JourneyBottomBar({required this.journey});

  @override
  Widget build(BuildContext context) {
    if (journey.currentPhase == JourneyPhase.journeyComplete) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                journey.resetJourney();
                journey.closeJourneyScreen();
              },
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Map'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppConstants.nairobiGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (journey.currentPhase == JourneyPhase.approachingDestination) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => journey.markArrivedAtStage(),
              icon: const Icon(Icons.directions_walk),
              label: Text(journey.largeText
                  ? 'I Have Alighted — Walk to Destination'
                  : 'I Have Alighted'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (journey.currentPhase == JourneyPhase.alighting) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => journey.markWalkingToDestination(),
              icon: const Icon(Icons.directions_walk),
              label: const Text('Walk to Destination'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppConstants.nairobiGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (journey.currentPhase == JourneyPhase.finalWalking) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => journey.markJourneyComplete(),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Arrived at Destination'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppConstants.nairobiGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _RidingStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool largeText;

  const _RidingStat({
    required this.icon,
    required this.value,
    required this.label,
    this.largeText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: largeText ? 22 : 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: largeText ? 16 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: largeText ? 13 : 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool largeText;

  const _InfoRow({
    required this.icon,
    required this.label,
    this.largeText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: largeText ? 20 : 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: largeText ? 16 : 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PhaseBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
