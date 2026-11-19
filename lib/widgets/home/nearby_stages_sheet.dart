import 'package:flutter/material.dart';

import '../../design/navi_colors.dart';
import '../../design/navi_typography.dart';
import '../../models/app_settings.dart';
import '../../models/transport_models.dart';
import '../../utils/distance_formatter.dart';
import '../../widgets/nearby_stages_list.dart' show NearbyStageEntry;
import '../../widgets/route_badge.dart';

/// What the nearby list should show right now.
enum NearbyStagesStatus {
  /// Waiting for a GPS fix (skeleton rows).
  locating,

  /// Location permission denied.
  denied,

  /// A fix was granted but timed out.
  timedOut,

  /// A fix exists but no stage is within range.
  empty,

  /// Real, sorted stages are available.
  ready,
}

/// The "Nearby Stages" bottom sheet on the Home screen.
///
/// It owns the [DraggableScrollableSheet] and reports its current extent back
/// to [HomeScreen] (which positions the map controls above it and hides them
/// while the sheet is expanded past 60%). All stage and distance values come
/// from the caller's existing nearest-stage list and the shared
/// [DistanceFormatter] — nothing is computed or hardcoded here.
class NearbyStagesSheet extends StatefulWidget {
  /// Height of one stage row.
  static const double rowHeight = 56;

  /// Handle (16) + title row (48) + three rows (168) + bottom pad (8).
  static const double minContentHeight = 240;

  final double initialSize;
  final double minSize;
  final double maxSize;
  final NearbyStagesStatus status;
  final List<NearbyStageEntry> entries;
  final DistanceUnit distanceUnit;
  final ValueChanged<StageModel> onStageTap;
  final ValueChanged<double>? onSizeChanged;
  final VoidCallback onEnableLocation;
  final VoidCallback? onOpenSettings;
  final bool permanentlyDenied;
  final VoidCallback? onRetry;

  const NearbyStagesSheet({
    super.key,
    required this.initialSize,
    required this.minSize,
    required this.maxSize,
    required this.status,
    required this.entries,
    required this.distanceUnit,
    required this.onStageTap,
    this.onSizeChanged,
    required this.onEnableLocation,
    this.onOpenSettings,
    this.permanentlyDenied = false,
    this.onRetry,
  });

  @override
  State<NearbyStagesSheet> createState() => _NearbyStagesSheetState();
}

class _NearbyStagesSheetState extends State<NearbyStagesSheet> {
  late final DraggableScrollableController _controller =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_reportExtent);
  }

  @override
  void dispose() {
    _controller.removeListener(_reportExtent);
    _controller.dispose();
    super.dispose();
  }

  void _reportExtent() {
    if (!_controller.isAttached) return;
    final callback = widget.onSizeChanged;
    if (callback == null) return;
    final size = _controller.size;
    // The controller notifies while the sheet is being laid out, so hand the
    // value back after the frame instead of mutating parent state mid-layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(size);
    });
  }

  /// "See all →" expands the sheet to its maximum extent.
  void _expand() {
    if (!_controller.isAttached) return;
    _controller.animateTo(
      widget.maxSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: widget.initialSize,
      minChildSize: widget.minSize,
      maxChildSize: widget.maxSize,
      expand: false,
      builder: (context, scrollController) {
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Container(
            decoration: BoxDecoration(
              color: NaviColors.surface(isDark),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildHandle(isDark)),
                SliverToBoxAdapter(child: _buildTitleRow(isDark)),
                ..._buildBody(isDark),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle(bool isDark) {
    return Container(
      height: 16,
      alignment: Alignment.center,
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: NaviColors.dividerC(isDark),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildTitleRow(bool isDark) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.directions_bus,
                size: 20, color: NaviColors.transitGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nearby Stages',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: NaviType.uiFontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: NaviColors.textPrimary(isDark),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'See all nearby stages',
              child: InkWell(
                onTap: _expand,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints:
                      const BoxConstraints(minHeight: 48, minWidth: 48),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    'See all →',
                    style: TextStyle(
                      fontFamily: NaviType.uiFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NaviColors.transitGreen,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody(bool isDark) {
    switch (widget.status) {
      case NearbyStagesStatus.locating:
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Finding stages near you...',
                style: NaviType.caption
                    .copyWith(color: NaviColors.textSecondary(isDark)),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: 3,
            itemBuilder: (_, __) => _SkeletonRow(isDark: isDark),
          ),
        ];
      case NearbyStagesStatus.denied:
        return [
          SliverToBoxAdapter(
            child: _MessageRow(
              isDark: isDark,
              icon: Icons.location_off,
              message: 'Turn on location to see nearby stages',
              action: widget.permanentlyDenied
                  ? 'Open settings'
                  : 'Enable location',
              onAction: widget.permanentlyDenied
                  ? widget.onOpenSettings
                  : widget.onEnableLocation,
            ),
          ),
        ];
      case NearbyStagesStatus.timedOut:
        return [
          SliverToBoxAdapter(
            child: _MessageRow(
              isDark: isDark,
              icon: Icons.my_location,
              message: 'Still finding your location',
              action: 'Try again',
              onAction: widget.onRetry,
            ),
          ),
        ];
      case NearbyStagesStatus.empty:
        return [
          SliverToBoxAdapter(
            child: _MessageRow(
              isDark: isDark,
              icon: Icons.directions_bus,
              message: 'No stages nearby yet',
            ),
          ),
        ];
      case NearbyStagesStatus.ready:
        return [
          SliverList.builder(
            itemCount: widget.entries.length,
            itemBuilder: (context, index) {
              final entry = widget.entries[index];
              return _StageRow(
                entry: entry,
                nearest: index == 0,
                distanceUnit: widget.distanceUnit,
                isDark: isDark,
                onTap: () => widget.onStageTap(entry.stage),
              );
            },
          ),
        ];
    }
  }
}

class _StageRow extends StatelessWidget {
  final NearbyStageEntry entry;
  final bool nearest;
  final DistanceUnit distanceUnit;
  final bool isDark;
  final VoidCallback onTap;

  const _StageRow({
    required this.entry,
    required this.nearest,
    required this.distanceUnit,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final distance =
        DistanceFormatter.format(entry.distanceMeters, unit: distanceUnit);
    final subtitle = nearest ? '$distance away · Nearest' : '$distance away';
    final routes = entry.stage.routes.take(2).toList();
    final extraRoutes = entry.stage.routes.length - routes.length;

    return SizedBox(
      height: NearbyStagesSheet.rowHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: NaviColors.transitGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    size: 20,
                    color: NaviColors.transitGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.stage.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: NaviType.uiFontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: NaviColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: NaviType.uiFontFamily,
                          fontSize: 13,
                          color: NaviColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                if (routes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  for (final route in routes) ...[
                    RouteBadge(routeNumber: route),
                    const SizedBox(width: 4),
                  ],
                  if (extraRoutes > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: NaviColors.psvYellow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+$extraRoutes',
                        style: const TextStyle(
                          fontFamily: NaviType.uiFontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: NaviColors.ink,
                        ),
                      ),
                    ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: NaviColors.textSecondary(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  final bool isDark;

  const _SkeletonRow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fill = NaviColors.dividerC(isDark);
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        );

    return SizedBox(
      height: NearbyStagesSheet.rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(140, 12),
                  const SizedBox(height: 8),
                  bar(80, 10),
                ],
              ),
            ),
            bar(36, 20),
          ],
        ),
      ),
    );
  }
}

/// A single informative row with an optional action button (permission,
/// timeout and empty states).
class _MessageRow extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  const _MessageRow({
    required this.isDark,
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: NearbyStagesSheet.rowHeight),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: NaviColors.transitGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: NaviColors.transitGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: NaviType.uiFontFamily,
                fontSize: 14,
                color: NaviColors.textPrimary(isDark),
              ),
            ),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: NaviColors.transitGreen,
                minimumSize: const Size(48, 48),
                textStyle: const TextStyle(
                  fontFamily: NaviType.uiFontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}
