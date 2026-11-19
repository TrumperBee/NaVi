import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';
import '../../design/navi_typography.dart';
import 'active_nav_data.dart';
import 'nav_banner.dart' show NavModeTile;

/// The top of the bottom sheet: remaining time and distance/arrival on the
/// left, the active mode (route number or "Walking") on the right.
///
/// The time and distance are fixed-width with tabular figures so the row never
/// reflows when the estimate ticks down.
class NavSummaryRow extends StatelessWidget {
  final ActiveNavData data;
  final bool isDark;

  const NavSummaryRow({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 34,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      data.remainingTimeLabel,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: NaviType.uiFontFamily,
                        fontSize: 32,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                        color: NaviColors.textPrimary(isDark),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 18,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      data.distanceAndArrivalLine,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: NaviType.uiFontFamily,
                        fontSize: 14,
                        color: NaviColors.textSecondary(isDark),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: NaviColors.dividerC(isDark),
        ),
        Expanded(
          flex: 6,
          child: Row(
            children: [
              NavModeTile(icon: _iconFor(data.modeTitle)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.modeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: NaviType.uiFontFamily,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: NaviColors.textPrimary(isDark),
                      ),
                    ),
                    if (data.modeSubtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        data.modeSubtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: NaviType.uiFontFamily,
                          fontSize: 13,
                          color: NaviColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _iconFor(String title) {
    if (title == 'Walking') return Icons.directions_walk;
    if (title == 'Arrived') return Icons.flag_outlined;
    return Icons.directions_bus;
  }
}
