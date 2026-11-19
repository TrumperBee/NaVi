import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';
import '../../design/navi_typography.dart';
import 'route_preview_theme.dart';

/// Floating chrome above the preview map: the back circle, the centred
/// "Route Details" capsule and the re-fit button.
class RoutePreviewTopBar extends StatelessWidget {
  final VoidCallback onBack;

  const RoutePreviewTopBar({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: NaviColors.surface(isDark),
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onBack,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.arrow_back,
                        size: 22,
                        color: NaviColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: NaviColors.surface(isDark),
                elevation: 4,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Text(
                    'Route Details',
                    style: TextStyle(
                      fontFamily: NaviType.uiFontFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: NaviColors.textPrimary(isDark),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular 44dp "fit the whole route" button that sits just above the docked
/// sheet.
class RoutePreviewFitButton extends StatelessWidget {
  final VoidCallback onPressed;

  const RoutePreviewFitButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: NaviColors.surface(isDark),
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.center_focus_strong_outlined,
            size: 22,
            color: RoutePreviewTheme.emerald,
          ),
        ),
      ),
    );
  }
}
