import '../../data/fare_matrix_seed.dart';
import '../../models/active_journey.dart';
import '../../models/route_segment.dart';
import '../../models/transport_models.dart';
import '../../utils/distance_formatter.dart';
import '../pre_trip_card.dart' show PreTripExtras;

/// Which shape the Route Preview takes.
///
/// - [destination]: a full journey preview (walk → ride → walk) with the
///   "Other Routes" list.
/// - [stage]: the user asked to walk to a stage, so the sheet shows the walk
///   plus every route that serves that stage.
enum RoutePreviewMode { destination, stage }

/// Which icon a preview metric row uses.
enum RoutePreviewMetricKind { walk, ride }

/// One of the three metric columns: "8 min" with an optional "(650 m)" or
/// "(12 stops)" bracket underneath.
class RoutePreviewMetric {
  final RoutePreviewMetricKind kind;
  final String time;
  final String? detail;

  const RoutePreviewMetric({
    required this.kind,
    required this.time,
    this.detail,
  });
}

/// The single derivation object behind the Route Preview sheet.
///
/// Every string here is read from the confirmed [ActiveJourney], the selected
/// [PathOption] and the stage catalogue — nothing is sample content. Metric
/// values are derived once so the pill, the title, the metrics and the banner
/// can never disagree with each other.
class RoutePreviewData {
  /// "Makadara Stage → Utawala" (or "Walk to Utawala" for a walk-only route).
  final String title;

  /// "via Jogoo Road" — only when the selected route's corridor is known.
  final String? subtitle;

  /// "Route 34" / "Walking".
  final String? routeLabel;

  final Duration totalDuration;
  final RoutePreviewMetric? firstWalk;
  final RoutePreviewMetric? ride;
  final RoutePreviewMetric? lastWalk;
  final int rideCount;

  /// Boarding stage's real name, when the route resolves it.
  final String? boardingStageName;

  /// Fare range, only when the calculator produced a ride fare (> 0).
  final String? fareLabel;

  /// True when at least one leg was drawn as a straight-line fallback because
  /// walking directions were unavailable. The sheet shows "Approximate route".
  final bool approximateRoute;

  /// Stage mode only: real minutes to reach the stage, rounded exactly like the
  /// metric chip so the banner and the header never disagree.
  final int? stageWalkMinutes;

  const RoutePreviewData({
    required this.title,
    required this.subtitle,
    required this.routeLabel,
    required this.totalDuration,
    required this.firstWalk,
    required this.ride,
    required this.lastWalk,
    required this.rideCount,
    required this.boardingStageName,
    required this.fareLabel,
    this.approximateRoute = false,
    this.stageWalkMinutes,
  });

  bool get hasRide => rideCount > 0;
  bool get isWalkOnly => rideCount == 0;
  int get transferCount => rideCount > 1 ? rideCount - 1 : 0;

  /// Banner sentence: "Board at Makadara Stage". Null when the boarding stage
  /// cannot be named (the banner is then omitted rather than invented).
  String? get boardingText =>
      boardingStageName == null ? null : 'Board at $boardingStageName';

  /// Stage-mode banner. Deliberately does NOT repeat the sheet title
  /// ("Walk to Makadara Stage") — it says how long the walk takes and points
  /// at the route list below instead.
  String? get stageBannerText {
    final minutes = stageWalkMinutes;
    if (minutes == null) return null;
    return 'About $minutes min to reach this stage. '
        'Matatus from here are listed below.';
  }

  factory RoutePreviewData.fromJourney({
    required ActiveJourney journey,
    required List<StageModel> stages,
    required String destinationLabel,
    PathOption? selectedPath,
    PreTripExtras? extras,
    bool stageMode = false,
  }) {
    StageModel? stageById(String? id) {
      if (id == null || id.isEmpty) return null;
      for (final stage in stages) {
        if (stage.id == id) return stage;
      }
      return null;
    }

    StageModel? asStage(Node node) =>
        node is StageModel ? node : stageById(node.id);

    final stageNodes =
        selectedPath?.path.where((node) => node.type == 'stage').toList() ??
            const <Node>[];

    final rideIndices = <int>[
      for (var i = 0; i < journey.segments.length; i++)
        if (journey.segments[i].mode == SegmentMode.matatu) i,
    ];
    final walkIndices = <int>[
      for (var i = 0; i < journey.segments.length; i++)
        if (journey.segments[i].mode == SegmentMode.walk) i,
    ];

    StageModel? firstRideStage;
    StageModel? lastRideStage;
    if (rideIndices.isNotEmpty) {
      firstRideStage =
          stageById(journey.segments[rideIndices.first].fromStageId);
      lastRideStage = stageById(journey.segments[rideIndices.last].toStageId);
    }

    String? boardingStageName;
    String? alightStageName;
    if (rideIndices.isNotEmpty) {
      boardingStageName = firstRideStage?.name;
      if (boardingStageName == null && stageNodes.isNotEmpty) {
        boardingStageName = stageNodes.first.name;
      }
      alightStageName = lastRideStage?.name;
      if (alightStageName == null && stageNodes.isNotEmpty) {
        alightStageName = stageNodes.last.name;
      }
    }

    final title = stageMode
        ? 'Walk to $destinationLabel'
        : rideIndices.isNotEmpty
            ? '${_nonEmpty(boardingStageName) ?? 'Start'} → '
                '${_nonEmpty(alightStageName) ?? destinationLabel}'
            : 'Walk to $destinationLabel';

    String? subtitle;
    if (!stageMode) {
      for (final node in stageNodes) {
        final corridor = asStage(node)?.corridor.trim() ?? '';
        if (corridor.isNotEmpty) {
          subtitle = 'via $corridor';
          break;
        }
      }
    }

    RoutePreviewMetric walkMetric(int index) {
      final segment = journey.segments[index];
      return RoutePreviewMetric(
        kind: RoutePreviewMetricKind.walk,
        time: formatDuration(segment.estimatedDuration),
        detail: '(${DistanceFormatter.format(segment.distanceMeters)})',
      );
    }

    RoutePreviewMetric? firstWalk;
    RoutePreviewMetric? lastWalk;
    if (stageMode) {
      if (journey.walkDistanceMeters > 0) {
        firstWalk = RoutePreviewMetric(
          kind: RoutePreviewMetricKind.walk,
          time: formatDuration(journey.walkDuration),
          detail: '(${DistanceFormatter.format(journey.walkDistanceMeters)})',
        );
      }
    } else if (walkIndices.isNotEmpty) {
      firstWalk = walkMetric(walkIndices.first);
      // A single walk leg is shown once; duplicating it as both "first" and
      // "last" would invent a step the journey does not have.
      if (walkIndices.length > 1) {
        lastWalk = walkMetric(walkIndices.last);
      }
    }

    RoutePreviewMetric? ride;
    if (!stageMode && rideIndices.isNotEmpty) {
      final stops = extras?.stopCounts[rideIndices.first];
      ride = RoutePreviewMetric(
        kind: RoutePreviewMetricKind.ride,
        time: formatDuration(journey.matatuDuration),
        detail: stops != null && stops > 0 ? '($stops stops)' : null,
      );
    }

    final routeNumbers = <String>[];
    for (final number in selectedPath?.routeNumbers ?? const <String>[]) {
      if (number.isEmpty || number.toLowerCase() == 'walk') continue;
      if (!routeNumbers.contains(number)) routeNumbers.add(number);
    }
    final routeLabel = stageMode || routeNumbers.isEmpty
        ? 'Walking'
        : routeNumbers.length == 1
            ? 'Route ${routeNumbers.first}'
            : 'Route ${routeNumbers.first} +${routeNumbers.length - 1}';

    // HARD RULE: never surface a KSh 0 ride fare.
    final fareLabel =
        !stageMode && rideIndices.isNotEmpty && journey.fareTotalKsh > 0
            ? _fareRangeLabel(journey)
            : null;

    final walkSeconds = journey.walkDuration.inSeconds;
    final stageWalkMinutes = stageMode && walkSeconds > 0
        ? (walkSeconds ~/ 60 + (walkSeconds % 60 >= 30 ? 1 : 0))
            .clamp(1, 999)
            .toInt()
        : null;

    return RoutePreviewData(
      title: title,
      subtitle: subtitle,
      routeLabel: routeLabel,
      totalDuration:
          stageMode ? journey.walkDuration : journey.totalEstimatedDuration,
      firstWalk: firstWalk,
      ride: ride,
      lastWalk: lastWalk,
      rideCount: stageMode ? 0 : rideIndices.length,
      boardingStageName: stageMode ? null : boardingStageName,
      fareLabel: fareLabel,
      approximateRoute: journey.hasApproximateSegment,
      stageWalkMinutes: stageWalkMinutes,
    );
  }

  /// Same fare-bracket sum as the rest of the app: the lowest and highest
  /// fare in each ride's verified/computed band, added across ride legs.
  static String _fareRangeLabel(ActiveJourney journey) {
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

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// "8 min", "1 hr 5 min" — rounded to the nearest minute, matching the rest
  /// of the app's duration copy.
  static String formatDuration(Duration d) {
    final roundedMinutes = d.inMinutes + (d.inSeconds % 60 >= 30 ? 1 : 0);
    if (roundedMinutes < 60) return '$roundedMinutes min';
    final h = roundedMinutes ~/ 60;
    final m = roundedMinutes % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }
}

/// One row in the "Other Routes" list (destination mode).
class RoutePreviewAlternative {
  final PathOption option;
  final String routeLabel;
  final String title;
  final String timeLabel;
  final String? fareLabel;

  const RoutePreviewAlternative({
    required this.option,
    required this.routeLabel,
    required this.title,
    required this.timeLabel,
    this.fareLabel,
  });

  factory RoutePreviewAlternative.from(
    PathOption option, {
    required String destinationLabel,
  }) {
    final routeNumbers = <String>[
      for (final number in option.routeNumbers)
        if (number.isNotEmpty && number.toLowerCase() != 'walk') number,
    ];
    final routeLabel =
        routeNumbers.isEmpty ? 'Walking' : 'Route ${routeNumbers.first}';

    Node? boardingNode;
    for (final node in option.path) {
      if (node.type == 'stage' && node.name.trim().isNotEmpty) {
        boardingNode = node;
        break;
      }
    }
    final title = boardingNode == null
        ? 'Walk to $destinationLabel'
        : '${boardingNode.name} → $destinationLabel';

    return RoutePreviewAlternative(
      option: option,
      routeLabel: routeLabel,
      title: title,
      timeLabel:
          '≈ ${RoutePreviewData.formatDuration(Duration(seconds: option.totalTime))}',
      // Only a positive calculator estimate is shown — never "KSh 0".
      fareLabel:
          option.totalFare > 0 ? 'KSh ${option.totalFare.round()}' : null,
    );
  }
}
