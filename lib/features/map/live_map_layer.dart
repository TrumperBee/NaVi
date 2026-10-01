import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/core/constants.dart';
import 'package:navi_app/features/journey/engines/journey_auto_detector.dart';
import 'package:navi_app/features/journey/engines/boarding_detection_engine.dart';
import 'mapbox_map_manager.dart';

/// Live-tracking annotations applied via MapboxMapManager.
/// The built-in location component (blue dot/puck) replaces the old
/// flutter_map markers from the previous implementation.
class LiveMapAnnotations {
  /// Add a route confidence badge as a point annotation.
  static Future<void> addRouteConfidenceMarker({
    required MapboxMapManager manager,
    required LatLng point,
    required double confidence,
  }) async {
    // Confidence is shown via the location puck color;
    // this method reserved for future custom overlay use.
  }

  /// Add a next-stop marker badge.
  static Future<void> addNextStopMarker({
    required MapboxMapManager manager,
    required LatLng point,
    required String name,
    required int remainingStops,
  }) async {
    // Reserved for future stop-marker implementation.
  }
}

class LiveInfoOverlay extends StatelessWidget {
  final JourneyAutoDetector detector;
  final bool largeText;

  const LiveInfoOverlay({
    super.key,
    required this.detector,
    this.largeText = false,
  });

  @override
  Widget build(BuildContext context) {
    final speed = detector.currentSpeed;
    final confidence = detector.routeConfidence;
    final movement = detector.movementState;
    final deviation = detector.lastDeviation;

    return Positioned(
      top: 90,
      left: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detector.isActive)
            _InfoChip(
              icon: Icons.speed,
              label: '${(speed * 3.6).toStringAsFixed(0)} km/h',
              largeText: largeText,
            ),
          if (detector.isActive && confidence > 0)
            _InfoChip(
              icon: Icons.route,
              label: '${(confidence * 100).toInt()}% match',
              color: _matchColor(confidence),
              largeText: largeText,
            ),
          _InfoChip(
            icon: _movementIcon(movement),
            label: _movementLabel(movement),
            largeText: largeText,
          ),
          if (deviation != null && deviation.type.name != 'none')
            _InfoChip(
              icon: Icons.warning_amber_rounded,
              label: deviation.message ?? 'Route deviation',
              color: Colors.red,
              largeText: largeText,
            ),
        ],
      ),
    );
  }

  Color _matchColor(double confidence) {
    if (confidence > 0.7) return AppConstants.nairobiGreen;
    if (confidence > 0.4) return Colors.orange;
    return Colors.red;
  }

  IconData _movementIcon(MovementState state) {
    if (state == MovementState.stationary) return Icons.location_on;
    if (state == MovementState.walking) return Icons.directions_walk;
    if (state == MovementState.running) return Icons.directions_run;
    if (state == MovementState.inVehicle) return Icons.directions_bus;
    return Icons.gps_off;
  }

  String _movementLabel(MovementState state) {
    if (state == MovementState.stationary) return 'Stationary';
    if (state == MovementState.walking) return 'Walking';
    if (state == MovementState.running) return 'Running';
    if (state == MovementState.inVehicle) return 'In matatu';
    return 'Detecting...';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool largeText;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
    this.largeText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: largeText ? 18 : 14, color: color ?? Colors.grey[700]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: largeText ? 14 : 11,
                fontWeight: FontWeight.w500,
                color: color ?? Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
