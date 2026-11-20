import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/active_journey.dart';
import '../../models/route_segment.dart';
import '../../models/transport_models.dart';
import '../../services/distance_calculator.dart';
import '../../utils/distance_formatter.dart';
import '../journey_info_panel.dart' show JourneyInfoPanel;
import '../pre_trip_card.dart' show PreTripExtras;
import 'active_nav_theme.dart';

/// What the floating instruction banner is describing.
enum NavBannerKind { walk, ride, arrived }

/// One resolved instruction-banner state.
///
/// [title] is the main instruction, [subtitle] the quiet second line and
/// [trailing] the distance (or stop count) on the right. Every string is
/// derived from the live [ActiveJourney]; nothing is invented.
class NavBannerContent {
  final NavBannerKind kind;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;

  const NavBannerContent({
    required this.kind,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  /// Identity of the *instruction* (not the distance), so a banner refresh
  /// while the user walks does not replay the 250ms transition on every fix.
  String get transitionKey => '${kind.name}|$title|${subtitle ?? ''}';
}

/// Which timeline row a step represents.
enum NavTimelineKind { walk, board, alight }

/// Progress of a timeline step relative to the live position.
enum NavStepState { completed, current, upcoming }

/// One row of the journey timeline.
class NavTimelineStep {
  final int segmentIndex;
  final NavTimelineKind kind;
  final NavStepState state;
  final String title;
  final String? subtitle;

  /// Estimated clock time at which this step finishes; null for completed
  /// steps (their time is in the past and is not shown).
  final DateTime? eta;

  /// Stops ridden between boarding and alighting, when the GTFS-derived
  /// extras carry a count for this leg.
  final int? stopCount;

  const NavTimelineStep({
    required this.segmentIndex,
    required this.kind,
    required this.state,
    required this.title,
    this.subtitle,
    this.eta,
    this.stopCount,
  });
}

/// Everything the Active Navigation screen renders that is not already on
/// [ActiveJourney] itself: banner wording per situation, the timeline with
/// states and estimated clock times, the summary labels and the arrival clock.
///
/// All of it is pure derivation — no timers, no map, no side effects — so the
/// screen can be rebuilt on every GPS fix without hiding business logic.
class ActiveNavData {
  final ActiveJourney journey;
  final List<StageModel> stages;
  final PreTripExtras? extras;

  /// Clock time the estimates are anchored to. Injected in tests.
  final DateTime now;

  ActiveNavData({
    required this.journey,
    this.stages = const [],
    this.extras,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  // ==================== SUMMARY ====================

  /// True when any leg is a straight-line fallback (walking directions were
  /// unavailable), so the panel shows "Approximate route".
  bool get isApproximate => journey.hasApproximateSegment;

  /// Only show a fare row when a real calculator estimate exists. Pure walks
  /// resolve to KSh 0 and are intentionally treated as "unknown / no fare".
  bool get hasFare => journey.fareTotalKsh > 0;

  /// The fare row copy, sourced from the fare calculator estimates stamped on
  /// each leg by the route builder (`RouteSegment.fareEstimate`).
  String get fareLabel => 'Fare KSh ${journey.fareTotalKsh}';

  /// Remaining time, rounded up so "40 s left" never reads "0 min" while the
  /// traveller is still moving.
  Duration get remainingDuration => journey.remainingDuration;

  String get remainingTimeLabel {
    if (journey.isComplete) return '0 min';
    final minutes = (remainingDuration.inSeconds / 60).ceil();
    return '${math.max(1, minutes)} min';
  }

  double get remainingDistanceMeters => journey.remainingDistanceMeters;

  /// "8.7 km • Arrive 10:15 AM" — the arrival clock is now + remaining time.
  String get distanceAndArrivalLine {
    final distance = DistanceFormatter.format(remainingDistanceMeters);
    final arrival = formatClock(now.add(remainingDuration));
    return '$distance • Arrive $arrival';
  }

  /// Title beside the tinted tile: the route number while riding, "Walking"
  /// on foot (and once arrived, "Arrived").
  String get modeTitle {
    if (journey.isComplete) return 'Arrived';
    final segment = journey.currentSegment;
    if (segment == null) return 'Arrived';
    if (segment.mode == SegmentMode.matatu) {
      final route = (segment.routeNumber ?? '').trim();
      return route.isEmpty ? 'Matatu' : 'Route $route';
    }
    return 'Walking';
  }

  /// "To Utawala" while riding, "To Makadara Stage" while walking to a stage.
  String? get modeSubtitle {
    if (journey.isComplete) return null;
    final segment = journey.currentSegment;
    if (segment == null) return null;
    final target = segment.mode == SegmentMode.matatu
        ? _alightStageName(segment)
        : _walkTarget(segment);
    if (target == null || target.isEmpty) return null;
    return 'To $target';
  }

  // ==================== INSTRUCTION BANNER ====================

  NavBannerContent get banner {
    final segment = journey.currentSegment;
    if (journey.isComplete || segment == null) {
      return const NavBannerContent(
        kind: NavBannerKind.arrived,
        icon: Icons.flag_outlined,
        title: 'You have arrived',
      );
    }

    if (segment.mode == SegmentMode.matatu) {
      final route = (segment.routeNumber ?? '').trim();
      final alight = _alightStageName(segment);
      final stops = _remainingStops(segment);
      return NavBannerContent(
        kind: NavBannerKind.ride,
        icon: Icons.directions_bus,
        title: route.isEmpty ? 'Stay on board' : 'Stay on Route $route',
        subtitle: alight == null ? null : 'Get off at $alight',
        trailing: stops != null
            ? (stops == 1 ? '1 stop' : '$stops stops')
            : _distanceLabel(_distanceToSegmentEnd(segment)),
      );
    }

    // Walking. Matatu legs carry no road names, walk legs only carry the
    // "Walk to …" label — no step geometry exists on the journey model, so
    // the honest instruction is the destination plus the distance left on
    // the leg. Road names are never invented.
    final title = _walkTitle(segment);
    return NavBannerContent(
      kind: NavBannerKind.walk,
      icon: Icons.directions_walk,
      title: title,
      subtitle: _nextActionSubtitle(segment),
      trailing: _distanceLabel(_distanceToSegmentEnd(segment)),
    );
  }

  /// Honest second line for a walk leg: the next real action from the journey
  /// model. A matatu leg with a route number reads "Then board Route 69"; no
  /// road names or intermediate stops are invented.
  String? _nextActionSubtitle(RouteSegment segment) {
    final index = journey.segments.indexOf(segment);
    if (index < 0 || index + 1 >= journey.segments.length) return null;
    final next = journey.segments[index + 1];

    if (next.mode == SegmentMode.matatu) {
      final route = (next.routeNumber ?? '').trim();
      if (route.isNotEmpty) return 'Then board Route $route';
      final stage = _stageName(next.fromStageId) ?? _labelTarget(next.label);
      return stage == null ? 'Then board a matatu' : 'Then board at $stage';
    }

    final target = _stageName(next.fromStageId) ?? _labelTarget(next.label);
    return target == null ? 'Then keep walking' : 'Then walk to $target';
  }

  /// Wording for a walk leg: the leg label (coordinate-guarded), or the
  /// explicit "Walk to your destination" once the last leg follows a ride.
  String _walkTitle(RouteSegment segment) {
    final index = journey.segments.indexOf(segment);
    final isLast = index >= 0 && index == journey.segments.length - 1;
    final rodeBefore = index > 0 &&
        journey.segments.take(index).any((s) => s.mode == SegmentMode.matatu);
    if (isLast && rodeBefore) return 'Walk to your destination';
    return JourneyInfoPanel.plainStepText(segment);
  }

  // ==================== TIMELINE ====================

  /// The full journey as timeline rows: one row per walk, and a board/alight
  /// pair per matatu leg so the ride reads as "get on here, get off there".
  ///
  /// Times are estimated from the remaining durations, anchored at [now]:
  /// the board row shows when boarding starts, the alight row when the ride
  /// ends. Completed rows carry no clock time.
  List<NavTimelineStep> get timeline {
    final steps = <NavTimelineStep>[];
    final currentIndex = journey.isComplete
        ? journey.segments.length
        : journey.currentSegmentIndex;
    var cursor = Duration.zero;

    for (var i = 0; i < journey.segments.length; i++) {
      final segment = journey.segments[i];
      final isCurrent = i == currentIndex && !journey.isComplete;
      final isDone = i < currentIndex || journey.isComplete;
      final state = isDone
          ? NavStepState.completed
          : isCurrent
              ? NavStepState.current
              : NavStepState.upcoming;

      final full = segment.estimatedDuration;
      final left = isCurrent
          ? Duration(
              seconds:
                  (full.inSeconds * (1 - journey.progressAlongCurrentSegment))
                      .round(),
            )
          : full;

      if (segment.mode == SegmentMode.matatu) {
        final route = (segment.routeNumber ?? '').trim();
        final boarding = _stageName(segment.fromStageId);
        final alight = _alightStageName(segment);
        final stops = extras?.stopCounts[i];

        steps.add(NavTimelineStep(
          segmentIndex: i,
          kind: NavTimelineKind.board,
          state: state,
          title: route.isEmpty ? 'Board your matatu' : 'Route $route',
          subtitle: boarding == null ? 'Board here' : 'Board at $boarding',
          eta: isDone ? null : now.add(cursor),
          stopCount: stops,
        ));
        steps.add(NavTimelineStep(
          segmentIndex: i,
          kind: NavTimelineKind.alight,
          // The ride has not ended yet when boarding is the current step, so
          // the alighting row is upcoming until the journey moves past it.
          state: isDone
              ? NavStepState.completed
              : isCurrent
                  ? NavStepState.upcoming
                  : state,
          title: alight == null ? 'Get off at your stop' : 'Get off at $alight',
          eta: isDone ? null : now.add(cursor + left),
        ));
      } else {
        steps.add(NavTimelineStep(
          segmentIndex: i,
          kind: NavTimelineKind.walk,
          state: state,
          title: _walkTitle(segment),
          eta: isDone ? null : now.add(cursor + left),
        ));
      }

      if (!isDone) cursor += left;
    }

    return steps;
  }

  /// Index of the first step that is not completed — the anchor of the
  /// collapsed timeline.
  int get currentStepIndex {
    final steps = timeline;
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].state != NavStepState.completed) return i;
    }
    return steps.isEmpty ? 0 : steps.length - 1;
  }

  /// The current step plus the next two, for the collapsed sheet. When the
  /// journey is finished the last steps are shown so the panel is never empty.
  List<NavTimelineStep> get collapsedTimeline {
    final all = timeline;
    if (all.isEmpty) return const [];
    final start = math.min(currentStepIndex, math.max(0, all.length - 1));
    final end = math.min(
      all.length,
      start + 1 + ActiveNavTheme.collapsedFutureSteps,
    );
    return all.sublist(start, end);
  }

  /// Intermediate stop names between the boarding and alighting stages of
  /// [segmentIndex], when routes.json had a matching direction.
  List<String> stopNamesFor(int segmentIndex) =>
      extras?.stopNames[segmentIndex] ?? const [];

  // ==================== HELPERS ====================

  StageModel? _stage(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final stage in stages) {
      if (stage.id == id) return stage;
    }
    return null;
  }

  String? _stageName(String? id) => _stage(id)?.name;

  /// The alighting stage's real name: id lookup first, then the segment
  /// label's "to …" tail (guarded against raw coordinates).
  String? _alightStageName(RouteSegment segment) {
    final byId = _stageName(segment.toStageId);
    if (byId != null) return byId;
    return _labelTarget(segment.label);
  }

  /// The place a walk leg leads to: the next segment's boarding stage when
  /// known, otherwise the leg label's own target.
  String? _walkTarget(RouteSegment segment) {
    final index = journey.segments.indexOf(segment);
    if (index >= 0 && index + 1 < journey.segments.length) {
      final next = journey.segments[index + 1];
      final name = _stageName(next.fromStageId);
      if (name != null) return name;
    }
    return _labelTarget(segment.label);
  }

  String? _labelTarget(String label) {
    const marker = ' to ';
    final index = label.lastIndexOf(marker);
    if (index < 0) return null;
    final tail = label.substring(index + marker.length).trim();
    if (tail.isEmpty || JourneyInfoPanel.looksLikeCoordinates(tail)) {
      return null;
    }
    return tail;
  }

  /// Distance still to walk/ride on the current leg — from the live position
  /// when one exists, otherwise the leg's own length.
  double _distanceToSegmentEnd(RouteSegment segment) {
    final position = journey.currentPosition;
    if (position == null) return segment.distanceMeters;
    return DistanceCalculator.distanceMeters(position, segment.endPoint);
  }

  /// Stops left on the current ride, scaled by progress along the leg.
  int? _remainingStops(RouteSegment segment) {
    final index = journey.segments.indexOf(segment);
    final total = index < 0 ? null : extras?.stopCounts[index];
    if (total == null || total <= 0) return null;
    final left = (total * (1 - journey.progressAlongCurrentSegment)).ceil();
    return left.clamp(1, total);
  }

  String _distanceLabel(double meters) => DistanceFormatter.format(meters);

  /// "10:15 AM" — 12-hour clock without relying on the platform locale, so
  /// the panel reads identically on every device.
  static String formatClock(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }
}
