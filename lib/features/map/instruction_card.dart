import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/core/constants.dart';
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/utils/distance_formatter.dart';

class InstructionCard extends StatelessWidget {
  final List<InstructionStep> instructions;
  final int currentInstructionIndex;
  final PathOption? selectedPath;
  final List<LatLng> routePolyline;
  final List<LatLng> traveledRoute;
  final List<LatLng> remainingRoute;
  final DateTime? navigationStartTime;

  const InstructionCard({
    super.key,
    required this.instructions,
    required this.currentInstructionIndex,
    this.selectedPath,
    this.routePolyline = const [],
    this.traveledRoute = const [],
    this.remainingRoute = const [],
    this.navigationStartTime,
  });

  @override
  Widget build(BuildContext context) {
    if (instructions.isEmpty) {
      return const SizedBox.shrink();
    }

    final instruction = instructions[currentInstructionIndex];
    final isLast = currentInstructionIndex == instructions.length - 1;

    double remainingDist = 0;
    for (int i = 0; i < remainingRoute.length - 1; i++) {
      remainingDist += _distanceBetween(remainingRoute[i], remainingRoute[i + 1]);
    }

    String eta = '';
    if (navigationStartTime != null && selectedPath != null) {
      final totalSeconds = selectedPath!.totalTime;
      final elapsedSeconds = DateTime.now().difference(navigationStartTime!).inSeconds;
      final remainingSeconds = max(0, totalSeconds - elapsedSeconds);
      if (remainingSeconds < 60) {
        eta = '${remainingSeconds}s';
      } else if (remainingSeconds < 3600) {
        eta = '${(remainingSeconds / 60).round()} min';
      } else {
        final h = remainingSeconds ~/ 3600;
        final m = (remainingSeconds % 3600) ~/ 60;
        eta = '${h}h ${m}m';
      }
    }

    final directionIcon = _directionIcon(instruction.type, instruction.instruction);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppConstants.nairobiGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(directionIcon, color: AppConstants.nairobiGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  instruction.instruction,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${currentInstructionIndex + 1}/${instructions.length}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (remainingDist > 0) ...[
                Icon(Icons.route, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatDistance(remainingDist),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                ),
              ],
              if (eta.isNotEmpty) ...[
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'ETA $eta',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                ),
              ],
              const Spacer(),
              if (selectedPath != null)
                _miniChip(Icons.attach_money, selectedPath!.formattedFare),
              if (selectedPath != null && selectedPath!.transferCount > 0) ...[
                const SizedBox(width: 4),
                _miniChip(Icons.transfer_within_a_station, '${selectedPath!.transferCount}x'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.grey[500]),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  IconData _directionIcon(String type, String instruction) {
    final lower = instruction.toLowerCase();
    if (lower.contains('turn right') || lower.contains('right')) return Icons.turn_right;
    if (lower.contains('turn left') || lower.contains('left')) return Icons.turn_left;
    if (lower.contains('continue') || lower.contains('straight')) return Icons.north;
    if (lower.contains('board') || lower.contains('route')) return Icons.directions_bus;
    if (lower.contains('alight') || lower.contains('arrive')) return Icons.flag;
    if (lower.contains('transfer')) return Icons.transfer_within_a_station;
    if (lower.contains('walk') || type == 'walk') return Icons.directions_walk;
    return Icons.navigation;
  }

  double _distanceBetween(LatLng a, LatLng b) {
    const R = 6371000;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final deltaLat = (b.latitude - a.latitude) * pi / 180;
    final deltaLng = (b.longitude - a.longitude) * pi / 180;
    final x = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
    return R * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  String _formatDistance(double meters) =>
      DistanceFormatter.format(meters);
}
