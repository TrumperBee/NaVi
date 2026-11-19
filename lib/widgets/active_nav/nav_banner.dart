import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';
import '../../design/navi_typography.dart';
import 'active_nav_data.dart';
import 'active_nav_theme.dart';

/// The floating instruction banner over the map: near-black card, mode icon,
/// the live instruction with its quiet second line, and the distance to the
/// next action on the right.
///
/// The content is derived in [ActiveNavData.banner]; this widget only lays it
/// out. Changing the *instruction* cross-fades/slides in 250ms; a distance
/// tick alone updates in place (no motion on every GPS fix).
class NavInstructionBanner extends StatelessWidget {
  final NavBannerContent content;

  const NavInstructionBanner({super.key, required this.content});

  /// Width reserved for the trailing distance so "850 m" → "1.2 km" never
  /// nudges the instruction text sideways.
  static const double trailingWidth = 68;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      height: ActiveNavTheme.bannerHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ActiveNavTheme.banner,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: _BannerRow(
                key: ValueKey(content.transitionKey),
                content: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerRow extends StatelessWidget {
  final NavBannerContent content;

  const _BannerRow({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: Icon(content.icon, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScaledLine(
                text: content.title,
                style: const TextStyle(
                  fontFamily: NaviType.uiFontFamily,
                  fontSize: 20,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (content.subtitle != null) ...[
                const SizedBox(height: 2),
                _ScaledLine(
                  text: content.subtitle!,
                  style: TextStyle(
                    fontFamily: NaviType.uiFontFamily,
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (content.trailing != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: NavInstructionBanner.trailingWidth,
            child: Text(
              content.trailing!,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: NaviType.uiFontFamily,
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Keeps a line at its designed size and only shrinks it when a long stage
/// name would otherwise clip on a narrow phone.
class _ScaledLine extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _ScaledLine({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, style: style),
      ),
    );
  }
}

/// Amber proximity strip docked directly under the instruction banner.
///
/// The owner auto-dismisses it after ~4s ([onDismiss] mirrors the close
/// button). It sits in the top stack, so it never reaches the map centre.
class NavProximityBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const NavProximityBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? const Color(0xFFFFE082) : const Color(0xFF78350F);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color:
            isDark ? const Color(0xFF3E2E00) : ActiveNavTheme.amberTint(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ActiveNavTheme.amber),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: ActiveNavTheme.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: NaviType.uiFontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: fg),
              visualDensity: VisualDensity.compact,
              tooltip: 'Dismiss alert',
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}

/// Small helper used by the panel's summary tile: a tinted square with an
/// icon, shared by the riding and walking states.
class NavModeTile extends StatelessWidget {
  final IconData icon;

  const NavModeTile({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: ActiveNavTheme.emeraldTint(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: ActiveNavTheme.emerald),
    );
  }
}

/// Dark/light aware secondary text used by the banner's neighbours.
Color navSecondaryText(BuildContext context) =>
    NaviColors.textSecondary(Theme.of(context).brightness == Brightness.dark);
