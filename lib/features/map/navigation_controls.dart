import 'package:flutter/material.dart';
import '../../core/constants.dart';

class NavigationControls extends StatelessWidget {
  final bool isNavigating;
  final bool hasLocation;
  final VoidCallback onStopNavigation;
  final VoidCallback onCenterLocation;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const NavigationControls({
    super.key,
    required this.isNavigating,
    required this.hasLocation,
    required this.onStopNavigation,
    required this.onCenterLocation,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: bottomInset + 20,
      right: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isNavigating)
            _buildButton(
              heroTag: 'stop_navigation',
              onPressed: onStopNavigation,
              backgroundColor: Colors.red,
              icon: Icons.stop,
            ),
          const SizedBox(height: 10),
          _buildButton(
            heroTag: 'my_location',
            onPressed: onCenterLocation,
            backgroundColor: Colors.white,
            icon: Icons.my_location,
            iconColor: hasLocation ? Colors.blue : Colors.grey,
          ),
          const SizedBox(height: 10),
          _buildButton(
            heroTag: 'zoom_in',
            onPressed: onZoomIn,
            backgroundColor: Colors.white,
            icon: Icons.add,
            iconColor: AppConstants.nairobiGreen,
          ),
          const SizedBox(height: 10),
          _buildButton(
            heroTag: 'zoom_out',
            onPressed: onZoomOut,
            backgroundColor: Colors.white,
            icon: Icons.remove,
            iconColor: AppConstants.nairobiGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String heroTag,
    required VoidCallback onPressed,
    Color backgroundColor = Colors.white,
    IconData? icon,
    Color? iconColor,
  }) {
    return SizedBox(
      width: 48,
      height: 48,
      child: FloatingActionButton(
        heroTag: heroTag,
        mini: false,
        onPressed: onPressed,
        backgroundColor: backgroundColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}
