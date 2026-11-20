import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/mapbox_config.dart';

/// Non-interactive overlay shown only in debug builds when the single
/// `MAPBOX_TOKEN` define was not supplied.
class MapboxTokenDebugBanner extends StatelessWidget {
  const MapboxTokenDebugBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || MapboxConfig.isConfigured) return child;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            top: 24,
            left: 12,
            right: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  MapboxConfig.missingTokenMessage,
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
