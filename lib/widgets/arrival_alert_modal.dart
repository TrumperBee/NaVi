import 'package:flutter/material.dart';
import 'package:navi_app/models/proximity_threshold.dart';

/// Destination-arrival confirmation dialog for the Active Navigation screen.
///
/// Proximity *warnings* no longer render as a top-of-screen overlay (they are
/// an amber strip docked above the info panel on the navigation screen); this
/// class now only owns the one-off "Arrived!" dialog.
class ArrivalAlertModal {
  static void showArrivalDialog(BuildContext context, ProximityAlertEvent event) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.flag, color: Colors.green[700], size: 28),
            const SizedBox(width: 8),
            const Text('Arrived!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 48, color: Colors.red[400]),
            const SizedBox(height: 12),
            Text(event.target.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('You have arrived at your destination.'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check_circle),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
