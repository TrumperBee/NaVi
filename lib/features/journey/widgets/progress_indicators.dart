import 'dart:async';
import 'package:flutter/material.dart';
import 'package:navi_app/core/constants.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';
import 'package:navi_app/utils/distance_formatter.dart';

class JourneyProgressBar extends StatelessWidget {
  final double progress;
  final bool highContrast;

  const JourneyProgressBar({
    super.key,
    required this.progress,
    this.highContrast = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 12,
        backgroundColor: highContrast
            ? Colors.grey[400]
            : Colors.grey[200],
        valueColor: AlwaysStoppedAnimation<Color>(
          progress > 0.75
              ? AppConstants.nairobiGreen
              : progress > 0.4
                  ? Colors.orange
                  : AppConstants.nairobiGreen,
        ),
      ),
    );
  }
}

class StopChips extends StatelessWidget {
  final int remainingStops;
  final int completedStops;
  final int totalStops;
  final bool largeText;

  const StopChips({
    super.key,
    required this.remainingStops,
    required this.completedStops,
    required this.totalStops,
    this.largeText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
          icon: Icons.done_all,
          label: '$completedStops done',
          color: AppConstants.nairobiGreen,
          largeText: largeText,
        ),
        const SizedBox(width: 8),
        _Chip(
          icon: Icons.route,
          label: '$remainingStops left',
          color: Colors.orange,
          largeText: largeText,
        ),
        const SizedBox(width: 8),
        _Chip(
          icon: Icons.location_on,
          label: '$totalStops total',
          color: Colors.blue,
          largeText: largeText,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool largeText;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    this.largeText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: largeText ? 18 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: largeText ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class EstimatedArrivalCountdown extends StatefulWidget {
  final DateTime estimatedArrival;
  final bool largeText;

  const EstimatedArrivalCountdown({
    super.key,
    required this.estimatedArrival,
    this.largeText = false,
  });

  @override
  State<EstimatedArrivalCountdown> createState() =>
      _EstimatedArrivalCountdownState();
}

class _EstimatedArrivalCountdownState
    extends State<EstimatedArrivalCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = widget.estimatedArrival.difference(now);
    final isOverdue = remaining.isNegative;

    if (isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Arriving now',
          style: TextStyle(
            fontSize: widget.largeText ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: AppConstants.nairobiGreen,
          ),
        ),
      );
    }

    final minutes = remaining.inMinutes;
    final hours = remaining.inHours;

    String display;
    if (hours > 0) {
      display = '${hours}h ${minutes % 60}m remaining';
    } else {
      display = '${minutes}min remaining';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 16, color: Colors.blue),
          const SizedBox(width: 6),
          Text(
            display,
            style: TextStyle(
              fontSize: widget.largeText ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }
}

class DistanceRemainingIndicator extends StatelessWidget {
  final int meters;
  final String label;
  final bool largeText;

  const DistanceRemainingIndicator({
    super.key,
    required this.meters,
    required this.label,
    this.largeText = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = DistanceFormatter.format(meters.toDouble());

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.straighten,
          size: largeText ? 20 : 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          '$display $label',
          style: TextStyle(
            fontSize: largeText ? 15 : 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class PhaseBanner extends StatelessWidget {
  final String label;
  final String emoji;
  final bool highContrast;

  const PhaseBanner({
    super.key,
    required this.label,
    required this.emoji,
    this.highContrast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: highContrast
            ? AppConstants.nairobiGreen.withValues(alpha: 0.2)
            : AppConstants.nairobiGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppConstants.nairobiGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: highContrast ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: AppConstants.nairobiGreen,
              ),
            ),
          ),
          Icon(
            Icons.navigation,
            color: AppConstants.nairobiGreen,
            size: 20,
          ),
        ],
      ),
    );
  }
}
