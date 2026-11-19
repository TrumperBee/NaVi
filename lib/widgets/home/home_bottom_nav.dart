import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';
import '../../design/navi_typography.dart';

/// The Home screen's own bottom navigation bar: Home / History / Settings.
///
/// It exists only on this screen (the active-navigation and pre-trip screens
/// keep their own bottom content). Only the selected tab's emerald colour is
/// animated (150ms) along with its 3dp underline.
class HomeBottomNav extends StatelessWidget {
  /// Bar height above the system inset.
  static const double height = 64;

  /// Duration for the tab colour change.
  static const Duration colorDuration = Duration(milliseconds: 150);

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const HomeBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const List<_Tab> _tabs = [
    _Tab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    _Tab(icon: Icons.history, activeIcon: Icons.history, label: 'History'),
    _Tab(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: NaviColors.surface(isDark),
        border: Border(
          top: BorderSide(color: NaviColors.dividerC(isDark), width: 1),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: _NavTab(
                  icon: _tabs[i].icon,
                  activeIcon: _tabs[i].activeIcon,
                  label: _tabs[i].label,
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = NaviColors.textSecondary(isDark);
    final color = selected ? NaviColors.transitGreen : secondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween:
                  Tween<double>(begin: selected ? 1 : 0, end: selected ? 1 : 0),
              duration: HomeBottomNav.colorDuration,
              curve: Curves.easeOut,
              builder: (context, t, child) => Icon(
                selected ? activeIcon : icon,
                size: 24,
                color: Color.lerp(secondary, NaviColors.transitGreen, t),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: HomeBottomNav.colorDuration,
              style: TextStyle(
                fontFamily: NaviType.uiFontFamily,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: HomeBottomNav.colorDuration,
              curve: Curves.easeOut,
              width: selected ? 20 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: NaviColors.transitGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
