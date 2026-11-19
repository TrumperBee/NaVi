import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';
import 'active_nav_theme.dart';

/// The floating map controls on the right edge of the Active Navigation map:
/// voice guidance, compass reset and a zoom capsule.
///
/// Every control is 44dp and uses the same shadowed white surface as the rest
/// of the design system; the voice button turns emerald while guidance is on.
class NavMapControls extends StatelessWidget {
  final bool voiceEnabled;
  final VoidCallback onToggleVoice;
  final VoidCallback? onResetBearing;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  const NavMapControls({
    super.key,
    required this.voiceEnabled,
    required this.onToggleVoice,
    this.onResetBearing,
    this.onZoomIn,
    this.onZoomOut,
  });

  /// Height of the stacked rail (two 44dp circles, two gaps and the zoom
  /// capsule). The screen uses it to keep the rail below the banner.
  static const double railHeight = 44 + 10 + 44 + 12 + 40 + 1 + 40;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
          isDark: isDark,
          tooltip: voiceEnabled ? 'Mute voice guidance' : 'Turn on voice',
          onTap: onToggleVoice,
          background: voiceEnabled ? ActiveNavTheme.emerald : null,
          child: Icon(
            voiceEnabled ? Icons.volume_up : Icons.volume_off,
            size: 22,
            color:
                voiceEnabled ? Colors.white : NaviColors.textSecondary(isDark),
          ),
        ),
        const SizedBox(height: 10),
        _CircleButton(
          isDark: isDark,
          tooltip: 'Reset map rotation',
          onTap: onResetBearing,
          child: Icon(
            Icons.explore_outlined,
            size: 22,
            color: NaviColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: NaviColors.surface(isDark),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CapsuleButton(
                tooltip: 'Zoom in',
                onTap: onZoomIn,
                icon: Icons.add,
                color: NaviColors.textPrimary(isDark),
              ),
              Container(
                width: 24,
                height: 1,
                color: NaviColors.dividerC(isDark),
              ),
              _CapsuleButton(
                tooltip: 'Zoom out',
                onTap: onZoomOut,
                icon: Icons.remove,
                color: NaviColors.textPrimary(isDark),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final Widget child;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isDark;
  final Color? background;

  const _CircleButton({
    required this.child,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background ?? NaviColors.surface(isDark),
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x33000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap ?? () {},
          child: SizedBox(
            width: ActiveNavTheme.controlSize,
            height: ActiveNavTheme.controlSize,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onTap;
  final IconData icon;
  final Color color;

  const _CapsuleButton({
    required this.tooltip,
    required this.onTap,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap ?? () {},
        child: SizedBox(
          width: ActiveNavTheme.controlSize,
          height: 40,
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}
