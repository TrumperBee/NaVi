import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../models/transport_models.dart';

// Navigation routing data is now rendered directly on the Mapbox map
// via MapboxLayers. This widget is kept for backward compatibility.
class NavigationOverlay extends StatelessWidget {
  final List<ll.LatLng> routePoints;
  final List<InstructionStep> instructions;
  final int currentInstructionIndex;
  final bool isTransportMode;

  const NavigationOverlay({
    super.key,
    required this.routePoints,
    required this.instructions,
    required this.currentInstructionIndex,
    required this.isTransportMode,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}