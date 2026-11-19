import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../data/fare_matrix_seed.dart';
import '../design/navi_colors.dart';
import '../design/navi_spacing.dart';
import '../design/navi_typography.dart';
import '../models/active_journey.dart';
import '../models/route_segment.dart';
import '../models/transport_models.dart';
import '../services/stage_route_summary.dart';
import '../utils/distance_formatter.dart';
import 'route_badge.dart';

typedef PreTripExtrasLoader = Future<PreTripExtras?> Function(
    ActiveJourney journey, List<StageModel> stages);

/// Derived presentation strings for the pre-trip timeline that are not carried
/// on the journey model itself: the boarding stage's headway sentence, the
/// headsign shown on each board row, and the number of stops between a leg's
/// two stages.
class PreTripExtras {
  final String? headwayText;
  final Map<int, String> headsigns;
  final Map<int, int> stopCounts;

  /// Display names of the stages passed between boarding and alighting, keyed
  /// by segment index. Empty when the route direction or the stage lookup
  /// misses, in which case the live timeline keeps the plain "N stops" row.
  final Map<int, List<String>> stopNames;

  const PreTripExtras({
    this.headwayText,
    this.headsigns = const {},
    this.stopCounts = const {},
    this.stopNames = const {},
  });

  /// Pure derivation over the decoded `routes.json` list — the same document
  /// [StageRouteSummaries] reads — so every value here is optional and the
  /// timeline degrades to plain sentences when a lookup misses.
  factory PreTripExtras.fromRoutes({
    required List<dynamic> routes,
    required ActiveJourney journey,
    required List<StageModel> stages,
    DateTime? now,
  }) {
    final matatuIndices = <int>[];
    for (var i = 0; i < journey.segments.length; i++) {
      if (journey.segments[i].mode == SegmentMode.matatu) {
        matatuIndices.add(i);
      }
    }
    if (matatuIndices.isEmpty) return const PreTripExtras();

    StageModel? stageOf(String? id) {
      if (id == null || id.isEmpty) return null;
      for (final stage in stages) {
        if (stage.id == id) return stage;
      }
      return null;
    }

    String? headway;
    final firstBoarding =
        stageOf(journey.segments[matatuIndices.first].fromStageId);
    if (firstBoarding != null) {
      headway = _rewordHeadway(StageRouteSummaries.stageFrequencyText(
        routes: routes,
        stageId: firstBoarding.id,
        stageName: firstBoarding.name,
        stageRouteNumbers: firstBoarding.routes,
        now: now,
      ));
    }

    final headsigns = <int, String>{};
    final stopCounts = <int, int>{};
    final stopNames = <int, List<String>>{};
    for (final i in matatuIndices) {
      final segment = journey.segments[i];
      final boarding = stageOf(segment.fromStageId);
      final rows = StageRouteSummaries.summarize(
        routes: routes,
        stageId: segment.fromStageId ?? '',
        stageName: boarding?.name ?? '',
        stageRouteNumbers: boarding?.routes ??
            [if (segment.routeNumber != null) segment.routeNumber!],
        now: now,
      );
      for (final row in rows) {
        if (row.routeNumber != segment.routeNumber) continue;
        if (row.headsign.isEmpty || row.headsign.contains('not recorded')) {
          break;
        }
        headsigns[i] = row.headsign;
        break;
      }

      final fromId = segment.fromStageId;
      final toId = segment.toStageId;
      if (fromId != null && toId != null) {
        final between = _stagesBetween(
          routes: routes,
          routeNumber: segment.routeNumber ?? '',
          fromId: fromId,
          toId: toId,
          fromName: boarding?.name,
          toName: stageOf(toId)?.name,
        );
        if (between != null && between.isNotEmpty) {
          stopCounts[i] = between.length;
          final names = <String>[];
          for (final token in between) {
            final name = _stageNameOfToken(token, stages);
            if (name != null) names.add(name);
          }
          if (names.isNotEmpty) stopNames[i] = names;
        }
      }
    }

    return PreTripExtras(
      headwayText: headway,
      headsigns: headsigns,
      stopCounts: stopCounts,
      stopNames: stopNames,
    );
  }

  /// "A matatu comes every 5-15 min right now" → "Matatus come every 5-15 min";
  /// no band recorded (or any sentence without a range) → null.
  static String? _rewordHeadway(String text) {
    final match = RegExp(r'every ([\d.]+(?:-[\d.]+)?) min').firstMatch(text);
    if (match == null) return null;
    return 'Matatus come every ${match.group(1)} min';
  }

  /// Stage ids passed between a leg's two stages, taken from the ordered stage
  /// list of the matching route direction. Returns null when either end cannot
  /// be resolved inside that list.
  static List<String>? _stagesBetween({
    required List<dynamic> routes,
    required String routeNumber,
    required String fromId,
    required String toId,
    String? fromName,
    String? toName,
  }) {
    if (routeNumber.isEmpty) return null;
    final fromKey = _normSep(fromName ?? fromId);
    final toKey = _normSep(toName ?? toId);
    final fromCore = _normSep(_nameCore(fromName ?? fromId));
    final toCore = _normSep(_nameCore(toName ?? toId));

    bool matches(String candidate, String key, String core) {
      final n = _normSep(candidate);
      if (n == key || n == core) return true;
      if (core.isEmpty) return false;
      return n.startsWith('$core-');
    }

    for (final raw in routes) {
      if (raw is! Map) continue;
      if (raw['route_number'] != routeNumber) continue;
      final directions = raw['directions'] as List? ?? const [];
      int? bestGap;
      List<String>? bestSlice;
      for (final rawDirection in directions) {
        if (rawDirection is! Map) continue;
        final ordered = (rawDirection['ordered_stages'] as List? ?? const [])
            .whereType<String>()
            .toList();
        for (var i = 0; i < ordered.length; i++) {
          if (!matches(ordered[i], fromKey, fromCore)) continue;
          for (var j = i + 1; j < ordered.length; j++) {
            if (!matches(ordered[j], toKey, toCore)) continue;
            final gap = j - i;
            if (bestGap == null || gap < bestGap) {
              bestGap = gap;
              bestSlice = ordered.sublist(i + 1, j);
            }
          }
        }
      }
      if (bestSlice != null) return bestSlice;
    }
    return null;
  }

  /// Resolves an `ordered_stages` token (a stage id such as `kwa_soko`) to the
  /// display name of the matching [StageModel]. Null when the token is not in
  /// the stage list, so an unknown stop is simply left out instead of shown as
  /// a machine id.
  static String? _stageNameOfToken(String token, List<StageModel> stages) {
    final key = _normSep(token);
    final core = _normSep(_nameCore(token));
    for (final stage in stages) {
      if (_normSep(stage.id) == key) return stage.name;
      if (core.isNotEmpty && _normSep(_nameCore(stage.name)) == core) {
        return stage.name;
      }
    }
    return null;
  }

  static String _normSep(String value) =>
      value.trim().toLowerCase().replaceAll('_', '-');

  static const _genericWords = {
    'stage',
    'bus',
    'stop',
    'terminal',
    'terminus',
    'station',
  };

  static String _nameCore(String value) {
    final words = value
        .trim()
        .toLowerCase()
        .split(RegExp(r'[\s_\-]+'))
        .where((w) => w.isNotEmpty && !_genericWords.contains(w))
        .toList();
    return words.join('_');
  }
}

/// Default [PreTripExtrasLoader]: reads the bundled `routes.json` and derives
/// the extras. Any failure returns null so the card renders plain sentences.
Future<PreTripExtras?> loadPreTripExtrasFromAssets(
    ActiveJourney journey, List<StageModel> stages) async {
  try {
    final raw = await rootBundle.loadString(StageRouteSummaries.routesAsset);
    final routes = jsonDecode(raw) as List<dynamic>;
    return PreTripExtras.fromRoutes(
      routes: routes,
      journey: journey,
      stages: stages,
    );
  } catch (_) {
    return null;
  }
}

/// The bottom-docked pre-trip card: route summary, option chips, leg timeline,
/// stage headway line and the Start Journey CTA — plus the skeleton (route
/// still building) and error (build failed) states.
class PreTripCard extends StatefulWidget {
  final bool loading;
  final bool error;
  final ActiveJourney? journey;
  final List<StageModel> stages;
  final List<PathOption> pathOptions;
  final PathOption? selectedPath;
  final ValueChanged<PathOption> onSelectOption;
  final VoidCallback onStartJourney;
  final VoidCallback onRetry;
  final PreTripExtrasLoader extrasLoader;

  const PreTripCard({
    super.key,
    required this.loading,
    required this.error,
    required this.journey,
    required this.stages,
    required this.pathOptions,
    required this.selectedPath,
    required this.onSelectOption,
    required this.onStartJourney,
    required this.onRetry,
    this.extrasLoader = loadPreTripExtrasFromAssets,
  });

  @override
  State<PreTripCard> createState() => _PreTripCardState();
}

class _PreTripCardState extends State<PreTripCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  ActiveJourney? _extrasFor;
  PreTripExtras? _extras;
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    _requestExtras();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (MediaQuery.of(context).disableAnimations) {
      _entrance.value = 1.0;
    } else {
      _entrance.forward();
    }
  }

  @override
  void didUpdateWidget(PreTripCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.journey, widget.journey)) {
      _requestExtras();
    }
  }

  void _requestExtras() {
    final journey = widget.journey;
    if (journey == null) {
      _extrasFor = null;
      _extras = null;
      return;
    }
    if (identical(_extrasFor, journey)) return;
    _extrasFor = journey;
    _extras = null;
    widget.extrasLoader(journey, widget.stages).then((value) {
      if (!mounted || !identical(_extrasFor, journey)) return;
      setState(() => _extras = value);
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final height =
        (MediaQuery.sizeOf(context).height * 0.4).clamp(180.0, double.infinity);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: _entrance,
        child: SizedBox(
          height: height,
          child: Container(
            key: const Key('preTripCardShell'),
            width: double.infinity,
            decoration: BoxDecoration(
              color: NaviColors.canvas(isDark),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: _content(isDark),
          ),
        ),
      ),
    );
  }

  Widget _content(bool isDark) {
    if (widget.error) return _errorContent(isDark);
    if (widget.loading || widget.journey == null) {
      return _skeletonContent(isDark);
    }
    return _readyContent(isDark, widget.journey!);
  }

  Widget _readyContent(bool isDark, ActiveJourney journey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                NaviSpacing.lg, NaviSpacing.lg, NaviSpacing.lg, NaviSpacing.sm),
            children: [
              _summaryRow(journey, isDark),
              if (widget.pathOptions.length > 1) ...[
                const SizedBox(height: 14),
                _chipsRow(isDark),
              ],
              const SizedBox(height: 14),
              _timeline(journey, isDark),
              if (_extras?.headwayText != null) ...[
                const SizedBox(height: 10),
                _headwayLine(isDark),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                NaviSpacing.lg, NaviSpacing.xs, NaviSpacing.lg, NaviSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onStartJourney,
                icon:
                    const Icon(Icons.navigation, color: Colors.white, size: 20),
                label: const Text(
                  'Start Journey',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NaviColors.transitGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(ActiveJourney journey, bool isDark) {
    final timeLabel = formatDuration(journey.totalEstimatedDuration);
    final distanceLabel = DistanceFormatter.format(journey.totalDistanceMeters);
    final fareLabel = fareRangeLabel(journey);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total time',
                style: NaviType.caption.copyWith(
                    fontSize: 10, color: NaviColors.textSecondary(isDark)),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  timeLabel,
                  style: NaviType.heroNumeral.copyWith(
                    fontSize: 30,
                    color: NaviColors.textPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
        _summaryDivider(isDark),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Distance',
                style: NaviType.caption.copyWith(
                    fontSize: 10, color: NaviColors.textSecondary(isDark)),
              ),
              const SizedBox(height: 2),
              Text(
                distanceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: NaviColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
        ),
        _summaryDivider(isDark),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fare',
                style: NaviType.caption.copyWith(
                    fontSize: 10, color: NaviColors.textSecondary(isDark)),
              ),
              const SizedBox(height: 2),
              Text(
                fareLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppConstants.nairobiGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NaviSpacing.sm),
      child: Container(
        width: 1,
        height: 34,
        color: NaviColors.dividerC(isDark),
      ),
    );
  }

  Widget _chipsRow(bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.pathOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: NaviSpacing.sm),
        itemBuilder: (context, index) {
          final option = widget.pathOptions[index];
          final selected = _isSelected(option);
          final routeNumber = option.routeNumbers.isNotEmpty
              ? option.routeNumbers.first
              : 'N/A';
          return Material(
            color: NaviColors.surface(isDark),
            elevation: selected ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NaviRadius.card),
              side: BorderSide(
                color: selected
                    ? NaviColors.textPrimary(isDark)
                    : NaviColors.dividerC(isDark),
                width: selected ? 2 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(NaviRadius.card),
              onTap: () => widget.onSelectOption(option),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: NaviSpacing.md, vertical: NaviSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RouteBadge(routeNumber: routeNumber),
                    const SizedBox(width: NaviSpacing.sm),
                    Text(
                      '${option.formattedTime} · ${option.formattedFare}',
                      style: NaviType.caption
                          .copyWith(color: NaviColors.textSecondary(isDark)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isSelected(PathOption option) {
    final selected = widget.selectedPath;
    if (selected == null) return false;
    if (identical(option, selected)) return true;
    return option.routeNumbers.join('|') == selected.routeNumbers.join('|') &&
        option.totalTime == selected.totalTime;
  }

  Widget _timeline(ActiveJourney journey, bool isDark) {
    final rows = <_TimelineRowData>[];
    final segments = journey.segments;
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final isLast = i == segments.length - 1;
      if (segment.mode == SegmentMode.walk) {
        final target = isLast ? 'your destination' : _walkTarget(segment);
        rows.add(_TimelineRowData(
          icon: Icons.directions_walk,
          color: AppConstants.nairobiGreen,
          sentence:
              'Walk ${_minutes(segment.estimatedDuration)} min to $target',
        ));
      } else {
        final headsign = _extras?.headsigns[i];
        final routeNumber = segment.routeNumber ?? '';
        rows.add(_TimelineRowData(
          icon: Icons.directions_bus,
          color: AppConstants.nairobiGreen,
          sentence: headsign == null
              ? 'Board Route $routeNumber'
              : 'Board Route $routeNumber towards $headsign',
          trailing: '${_minutes(segment.estimatedDuration)} min',
        ));
        final stops = _extras?.stopCounts[i];
        final alight = _alightTarget(segment);
        rows.add(_TimelineRowData(
          icon: Icons.flag,
          color: Colors.red,
          sentence: alight == null
              ? 'Get off here'
              : 'Get off at $alight'
                  '${stops == null ? '' : ' ($stops stops)'}',
        ));
      }
    }

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          _timelineRow(rows[i], isLast: i == rows.length - 1, isDark: isDark),
      ],
    );
  }

  Widget _timelineRow(_TimelineRowData row,
      {required bool isLast, required bool isDark}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: row.color.withValues(alpha: 0.1),
                ),
                child: Icon(row.icon, size: 16, color: row.color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: NaviColors.dividerC(isDark),
                  ),
                ),
            ],
          ),
          const SizedBox(width: NaviSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : NaviSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.sentence,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: NaviColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                  if (row.trailing != null) ...[
                    const SizedBox(width: NaviSpacing.sm),
                    Text(
                      row.trailing!,
                      style: NaviType.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: NaviColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headwayLine(bool isDark) {
    return Row(
      children: [
        Icon(Icons.schedule, size: 14, color: NaviColors.textSecondary(isDark)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _extras!.headwayText!,
            style: NaviType.caption
                .copyWith(color: NaviColors.textSecondary(isDark)),
          ),
        ),
      ],
    );
  }

  String _walkTarget(RouteSegment segment) {
    const prefix = 'Walk to ';
    final label = segment.label;
    if (label.startsWith(prefix)) {
      final target = label.substring(prefix.length).trim();
      return target.isEmpty ? 'your destination' : target;
    }
    return label;
  }

  String? _alightTarget(RouteSegment segment) {
    final stage = _stageById(segment.toStageId);
    if (stage != null) return stage.name;
    const marker = ' to ';
    final label = segment.label;
    final index = label.lastIndexOf(marker);
    if (index >= 0) {
      final target = label.substring(index + marker.length).trim();
      if (target.isNotEmpty) return target;
    }
    return null;
  }

  StageModel? _stageById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final stage in widget.stages) {
      if (stage.id == id) return stage;
    }
    return null;
  }

  Widget _skeletonContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _ShimmerArea(
            isDark: isDark,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(NaviSpacing.lg, NaviSpacing.lg,
                  NaviSpacing.lg, NaviSpacing.sm),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerBar(widthFactor: 0.5, height: 9),
                          SizedBox(height: 6),
                          _ShimmerBar(widthFactor: 0.7, height: 24),
                        ],
                      ),
                    ),
                    _summaryDivider(isDark),
                    const Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerBar(widthFactor: 0.6, height: 9),
                          SizedBox(height: 6),
                          _ShimmerBar(widthFactor: 0.8, height: 16),
                        ],
                      ),
                    ),
                    _summaryDivider(isDark),
                    const Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerBar(widthFactor: 0.5, height: 9),
                          SizedBox(height: 6),
                          _ShimmerBar(widthFactor: 0.7, height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                for (var i = 0; i < 3; i++) ...[
                  const Row(
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: NaviSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ShimmerBar(widthFactor: 0.6, height: 13),
                            SizedBox(height: 6),
                            _ShimmerBar(widthFactor: 0.35, height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (i < 2) const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                NaviSpacing.lg, NaviSpacing.xs, NaviSpacing.lg, NaviSpacing.lg),
            child: _ShimmerArea(
              isDark: isDark,
              child: const SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorContent(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(NaviSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 36, color: NaviColors.textSecondary(isDark)),
          const SizedBox(height: NaviSpacing.sm),
          Text(
            "Couldn't build your route.",
            textAlign: TextAlign.center,
            style: NaviType.cardTitle
                .copyWith(color: NaviColors.textPrimary(isDark)),
          ),
          const SizedBox(height: NaviSpacing.xs),
          Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: NaviType.caption
                .copyWith(color: NaviColors.textSecondary(isDark)),
          ),
          const SizedBox(height: NaviSpacing.lg),
          OutlinedButton(
            onPressed: widget.onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: NaviColors.transitGreen,
              side: const BorderSide(color: NaviColors.transitGreen),
              padding: const EdgeInsets.symmetric(
                  horizontal: NaviSpacing.xl, vertical: NaviSpacing.md),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NaviRadius.card)),
            ),
            child: const Text('Retry',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  static String formatDuration(Duration d) {
    final roundedMinutes = d.inMinutes + (d.inSeconds % 60 >= 30 ? 1 : 0);
    if (roundedMinutes < 60) return '$roundedMinutes min';
    final h = roundedMinutes ~/ 60;
    final m = roundedMinutes % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }

  static String fareRangeLabel(ActiveJourney journey) {
    var min = 0;
    var max = 0;
    var withEstimate = 0;
    for (final segment in journey.segments) {
      final estimate = segment.fareEstimate;
      if (segment.mode != SegmentMode.matatu || estimate == null) continue;
      final range = FareMatrix.getFareRange(estimate.tier, estimate.timeOfDay);
      min += range.first;
      max += range.last;
      withEstimate++;
    }
    if (withEstimate == 0) return 'KSh ${journey.fareTotalKsh}';
    if (min == max) return 'KSh $min';
    return 'KSh $min-$max';
  }

  static int _minutes(Duration duration) {
    final minutes = (duration.inSeconds / 60).round();
    return minutes < 1 ? 1 : minutes;
  }
}

class _TimelineRowData {
  final IconData icon;
  final Color color;
  final String sentence;
  final String? trailing;

  const _TimelineRowData({
    required this.icon,
    required this.color,
    required this.sentence,
    this.trailing,
  });
}

/// Sweeps a sheen across white skeleton shapes; the tint adapts to the card's
/// theme so the shimmer reads on both canvas colors. Static (no sweep) when
/// the platform requests reduced motion.
class _ShimmerArea extends StatefulWidget {
  final bool isDark;
  final Widget child;

  const _ShimmerArea({required this.isDark, required this.child});

  @override
  State<_ShimmerArea> createState() => _ShimmerAreaState();
}

class _ShimmerAreaState extends State<_ShimmerArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.of(context).disableAnimations) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base =
        widget.isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E1D8);
    final sheen =
        widget.isDark ? const Color(0xFF3F4245) : const Color(0xFFF3F1EA);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final sweep = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final center = -0.6 + (2.0 * sweep);
            return LinearGradient(
              colors: [base, sheen, base],
              stops: [
                center.clamp(0.0, 1.0),
                (center + 0.25).clamp(0.0, 1.0),
                (center + 0.5).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A skeleton line shaped like a content row. The bar is opaque white; the
/// surrounding [_ShimmerArea] tints it with the sweeping sheen.
class _ShimmerBar extends StatelessWidget {
  final double widthFactor;
  final double height;

  const _ShimmerBar({required this.widthFactor, required this.height});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: SizedBox(height: height),
      ),
    );
  }
}
