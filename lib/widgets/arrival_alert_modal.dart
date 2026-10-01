import 'package:flutter/material.dart';
import 'package:navi_app/models/proximity_threshold.dart';
import 'package:navi_app/core/constants.dart';

class ArrivalAlertModal {
  static OverlayEntry? _currentEntry;
  static DateTime? _lastBannerTime;

  static void showBanner(BuildContext context, ProximityAlertEvent event) {
    if (event.type == ProximityAlertType.arrivalConfirmed) {
      _showArrivalModal(context, event);
      return;
    }

    final now = DateTime.now();
    if (_lastBannerTime != null && now.difference(_lastBannerTime!) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastBannerTime = now;

    _removeCurrentBanner();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ProximityBanner(event: event, onDismiss: () => entry.remove()),
    );
    _currentEntry = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
      if (_currentEntry == entry) _currentEntry = null;
    });
  }

  static void _showArrivalModal(BuildContext context, ProximityAlertEvent event) {
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
            Text('You have arrived at your destination.'),
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

  static void _removeCurrentBanner() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static void dispose() {
    _removeCurrentBanner();
  }
}

class _ProximityBanner extends StatefulWidget {
  final ProximityAlertEvent event;
  final VoidCallback onDismiss;

  const _ProximityBanner({required this.event, required this.onDismiss});

  @override
  State<_ProximityBanner> createState() => _ProximityBannerState();
}

class _ProximityBannerState extends State<_ProximityBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + _slideAnimation.value,
          left: 16,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.nairobiGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppConstants.nairobiGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: AppConstants.nairobiGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.event.displayMessage,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: widget.onDismiss,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}