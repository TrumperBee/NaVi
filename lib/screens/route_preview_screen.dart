import 'package:flutter/material.dart';

import '../models/active_journey.dart';
import '../models/transport_models.dart';
import '../services/stage_route_summary.dart';
import '../widgets/pre_trip_card.dart' show PreTripExtras;
import '../widgets/route_preview/route_preview_chrome.dart';
import '../widgets/route_preview/route_preview_data.dart';
import '../widgets/route_preview/route_preview_sheet.dart';

/// The pre-trip Route Preview: the whole confirmed route on the map behind a
/// docked sheet that explains the journey and starts it.
///
/// The screen owns only presentation and the sheet controller. The map (and
/// its Mapbox annotations) stay with Home, which passes it in as [map]; this
/// keeps a single map instance alive across the preview → live-navigation
/// handoff. When [map] is null the screen renders chrome only (used when Home
/// stacks the preview above its existing full-screen map).
class RoutePreviewScreen extends StatefulWidget {
  final Widget? map;
  final RoutePreviewMode mode;
  final ActiveJourney? journey;
  final PathOption? selectedPath;
  final List<PathOption> pathOptions;
  final List<StageModel> stages;
  final PreTripExtras? extras;
  final StageModel? stage;
  final List<StageRouteSummary> stageRoutes;
  final String destinationLabel;
  final bool loading;
  final bool error;
  final VoidCallback onBack;
  final VoidCallback onStartJourney;
  final ValueChanged<PathOption> onSelectOption;
  final VoidCallback onRetry;
  final VoidCallback? onFitRoute;
  final ValueChanged<double>? onSheetExtentChanged;

  const RoutePreviewScreen({
    super.key,
    this.map,
    required this.mode,
    required this.journey,
    required this.selectedPath,
    this.pathOptions = const [],
    this.stages = const [],
    this.extras,
    this.stage,
    this.stageRoutes = const [],
    required this.destinationLabel,
    this.loading = false,
    this.error = false,
    required this.onBack,
    required this.onStartJourney,
    required this.onSelectOption,
    required this.onRetry,
    this.onFitRoute,
    this.onSheetExtentChanged,
  });

  /// The sheet's maximum height as a fraction of the screen.
  static const double maxExtent = 0.9;

  /// The sheet's minimum draggable height.
  static const double minExtent = 0.28;

  /// The height the sheet opens at so the "Start Journey" button is fully
  /// visible on both 360×640 and 412×915 phones.
  static const double initialExtentTargetPx = 380;

  static double initialExtentFor(Size size) {
    if (size.height <= 0) return minExtent;
    return (initialExtentTargetPx / size.height)
        .clamp(minExtent, maxExtent)
        .toDouble();
  }

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double? _extent;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  double _currentExtent(Size size) =>
      _extent ?? RoutePreviewScreen.initialExtentFor(size);

  void _onExtentChanged(double extent) {
    if ((_currentExtent(MediaQuery.sizeOf(context)) - extent).abs() < 0.005) {
      return;
    }
    setState(() => _extent = extent);
    widget.onSheetExtentChanged?.call(extent);
  }

  void _expandSheet() {
    if (!_sheetController.isAttached) return;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    _sheetController.animateTo(
      RoutePreviewScreen.maxExtent,
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final initialExtent = RoutePreviewScreen.initialExtentFor(size);
    final extent = _currentExtent(size);
    final stageMode = widget.mode == RoutePreviewMode.stage;
    final label = stageMode
        ? (widget.stage?.name ?? widget.destinationLabel)
        : widget.destinationLabel;

    final data = widget.journey == null
        ? null
        : RoutePreviewData.fromJourney(
            journey: widget.journey!,
            stages: widget.stages,
            destinationLabel: label,
            selectedPath: widget.selectedPath,
            extras: widget.extras,
            stageMode: stageMode,
          );

    final alternatives = <RoutePreviewAlternative>[
      if (widget.mode == RoutePreviewMode.destination &&
          widget.pathOptions.length > 1)
        for (final option in widget.pathOptions)
          if (!identical(option, widget.selectedPath))
            RoutePreviewAlternative.from(
              option,
              destinationLabel: widget.destinationLabel,
            ),
    ];

    final showSkeleton =
        widget.loading || (widget.journey == null && !widget.error);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.map != null) Positioned.fill(child: widget.map!),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: RoutePreviewTopBar(onBack: widget.onBack),
        ),
        if (widget.onFitRoute != null &&
            widget.journey != null &&
            !widget.error)
          Positioned(
            right: 16,
            bottom: size.height * extent + 24,
            child: RoutePreviewFitButton(onPressed: widget.onFitRoute!),
          ),
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            _onExtentChanged(notification.extent);
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: initialExtent,
            minChildSize: RoutePreviewScreen.minExtent,
            maxChildSize: RoutePreviewScreen.maxExtent,
            snap: false,
            builder: (context, scrollController) => RoutePreviewSheet(
              mode: widget.mode,
              data: data,
              alternatives: alternatives,
              destinationLabel: label,
              stageName: widget.stage?.name,
              stageRoutes: widget.stageRoutes,
              loading: showSkeleton,
              error: widget.error,
              scrollController: scrollController,
              onStartJourney: widget.onStartJourney,
              onRetry: widget.onRetry,
              onSelectAlternative: widget.onSelectOption,
              onSeeAllRoutes: widget.mode == RoutePreviewMode.destination &&
                      alternatives.isNotEmpty
                  ? _expandSheet
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
