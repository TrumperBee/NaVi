import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';

/// The floating map controls on the Home screen: layers, zoom, re-center.
///
/// Purely presentational — [HomeScreen] owns the map camera, the style toggle
/// and the sheet extent that decides where this column sits and whether it is
/// visible.
class HomeMapControls extends StatelessWidget {
  /// Circle diameter for the layers button.
  static const double layersSize = 44;

  /// Width of the zoom capsule (the two buttons are this wide and 44 tall).
  static const double zoomWidth = 44;

  /// Diameter for the re-center button.
  static const double recenterSize = 48;

  final bool satellite;
  final VoidCallback onToggleLayers;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;

  const HomeMapControls({
    super.key,
    required this.satellite,
    required this.onToggleLayers,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = NaviColors.surface(isDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
          size: layersSize,
          surface: surface,
          tooltip: satellite ? 'Map style: satellite' : 'Map style: standard',
          onTap: onToggleLayers,
          child: Icon(
            satellite ? Icons.satellite_alt : Icons.layers_outlined,
            size: 20,
            color: satellite ? NaviColors.ink : NaviColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 8),
        _ZoomCapsule(
          width: zoomWidth,
          surface: surface,
          isDark: isDark,
          onZoomIn: onZoomIn,
          onZoomOut: onZoomOut,
        ),
        const SizedBox(height: 8),
        _CircleButton(
          size: recenterSize,
          surface: surface,
          tooltip: 'Re-centre on my location',
          onTap: onRecenter,
          child: const Icon(
            Icons.navigation,
            size: 22,
            color: NaviColors.signalBlue,
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final double size;
  final Color surface;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  const _CircleButton({
    required this.size,
    required this.surface,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: surface,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: Colors.black26,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _ZoomCapsule extends StatelessWidget {
  final double width;
  final Color surface;
  final bool isDark;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _ZoomCapsule({
    required this.width,
    required this.surface,
    required this.isDark,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(22),
      elevation: 3,
      shadowColor: Colors.black26,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZoomButton(
              icon: Icons.add,
              label: 'Zoom in',
              isDark: isDark,
              onTap: onZoomIn,
            ),
            Container(
              height: 1,
              width: width * 0.5,
              color: NaviColors.dividerC(isDark),
            ),
            _ZoomButton(
              icon: Icons.remove,
              label: 'Zoom out',
              isDark: isDark,
              onTap: onZoomOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _ZoomButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: HomeMapControls.zoomWidth,
      height: 44,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Icon(
            icon,
            size: 20,
            color: NaviColors.textPrimary(isDark),
          ),
        ),
      ),
    );
  }
}
