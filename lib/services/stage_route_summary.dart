import 'dart:convert';
import 'dart:math' show max, min;

import 'package:flutter/services.dart';

import 'package:navi_app/models/transport_models.dart';

/// One route row on the Stage Details sheet: the route number shown in the
/// yellow PSV badge, the destination(s) its directions headsign toward at
/// this stage, and the route's headway sentence for the current time band.
class StageRouteSummary {
  final String routeNumber;
  final String headsign;
  final String headwayText;

  const StageRouteSummary({
    required this.routeNumber,
    required this.headsign,
    required this.headwayText,
  });
}

/// Stage-centric view over `assets/data/gtfs_import/routes.json`.
///
/// Resolves the app's stage (a seed/Firestore stage whose id usually does not
/// exist verbatim in the GTFS bundle) to the GTFS stage ids it corresponds to,
/// then derives the sheet's rows from every route direction that serves one
/// of those stages — per spec §1.2, `routes_served` is always derived from
/// direction data, never from a hand-maintained list.
///
/// Resolution: match GTFS stage ids against the app stage's id and against a
/// "name core" (the stage name lowercased with trailing generic words such as
/// Stage/Bus/Stop/Station stripped, slugged), so `Makadara Stage` matches the
/// whole `makadara*` id family (makadara_1, makadara-dc, ...). The family is
/// then narrowed to ids served by at least one of the stage's known route
/// numbers when such ids exist — this keeps a 24km-away `makadara_2` out of
/// the Makadara sheet — and kept whole when the known list matches nothing
/// (hand lists are legacy and may be stale).
class StageRouteSummaries {
  StageRouteSummaries._();

  static const String routesAsset = 'assets/data/gtfs_import/routes.json';

  /// Shown whenever headway data is missing for the current time band —
  /// never "coming soon".
  static const String noFrequencyText = 'Frequency not recorded yet';

  static const String _destinationMissingText = 'destination not recorded yet';

  // Nairobi wall-clock minutes of day for the peak bands (UTC+3, no DST):
  // 06:30-09:30 and 16:30-20:00, both inclusive.
  static const int _peakMorningStart = 6 * 60 + 30;
  static const int _peakMorningEnd = 9 * 60 + 30;
  static const int _peakEveningStart = 16 * 60 + 30;
  static const int _peakEveningEnd = 20 * 60;

  static const Set<String> _genericNameWords = {
    'stage',
    'bus',
    'stop',
    'terminal',
    'terminus',
    'station',
  };

  static Future<List<dynamic>>? _decodedRoutes;

  static Future<List<dynamic>> _routes() =>
      _decodedRoutes ??= rootBundle
          .loadString(routesAsset)
          .then((raw) => jsonDecode(raw) as List<dynamic>);

  /// Loads the GTFS-derived rows for [stage]; returns an empty list if the
  /// bundle cannot be read so the sheet can fall back to its legacy chips.
  static Future<List<StageRouteSummary>> loadForStage(
    StageModel stage, {
    DateTime? now,
  }) async {
    try {
      final routes = await _routes();
      return summarize(
        routes: routes,
        stageId: stage.id,
        stageName: stage.name,
        stageRouteNumbers: stage.routes,
        now: now,
      );
    } catch (_) {
      return const <StageRouteSummary>[];
    }
  }

  /// Stage-level frequency sentence for the wait-time card, aggregated over
  /// every route that serves [stage] in the current time band.
  static Future<String> loadStageFrequency(
    StageModel stage, {
    DateTime? now,
  }) async {
    try {
      final routes = await _routes();
      return stageFrequencyText(
        routes: routes,
        stageId: stage.id,
        stageName: stage.name,
        stageRouteNumbers: stage.routes,
        now: now,
      );
    } catch (_) {
      return noFrequencyText;
    }
  }

  /// Pure core of [loadForStage]: one row per GTFS route whose direction
  /// serves the stage, in routes.json order. [now] is an absolute instant
  /// (defaults to the current time); it is converted to Nairobi wall clock to
  /// pick the peak/off-peak headway band.
  static List<StageRouteSummary> summarize({
    required List<dynamic> routes,
    String stageId = '',
    String stageName = '',
    List<String> stageRouteNumbers = const [],
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final rows = <StageRouteSummary>[];
    for (final entry in _servingRoutes(
      routes: routes,
      stageId: stageId,
      stageName: stageName,
      stageRouteNumbers: stageRouteNumbers,
    )) {
      final route = entry['route'] as Map<String, dynamic>;
      final directions = entry['directions'] as List<Map<String, dynamic>>;
      final headsigns = <String>[];
      for (final direction in directions) {
        final headsign = (direction['headsign'] as String? ?? '').trim();
        if (headsign.isNotEmpty && !headsigns.contains(headsign)) {
          headsigns.add(headsign);
        }
      }
      rows.add(StageRouteSummary(
        routeNumber: (route['route_number'] as String?) ?? '',
        headsign: headsigns.isEmpty
            ? _destinationMissingText
            : headsigns.join(' / '),
        headwayText: headwayTextForRange(_chosenRange(route, at)),
      ));
    }
    return rows;
  }

  /// Pure core of [loadStageFrequency]: the widest chosen-band headway range
  /// across all routes serving the stage, as a commuter-facing sentence.
  static String stageFrequencyText({
    required List<dynamic> routes,
    String stageId = '',
    String stageName = '',
    List<String> stageRouteNumbers = const [],
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    num? lowest;
    num? highest;
    for (final entry in _servingRoutes(
      routes: routes,
      stageId: stageId,
      stageName: stageName,
      stageRouteNumbers: stageRouteNumbers,
    )) {
      final route = entry['route'] as Map<String, dynamic>;
      final range = _rangePair(_chosenRange(route, at));
      if (range == null) continue;
      lowest = lowest == null ? range.$1 : min(lowest, range.$1);
      highest = highest == null ? range.$2 : max(highest, range.$2);
    }
    if (lowest == null || highest == null) return noFrequencyText;
    return _headwaySentence(lowest, highest);
  }

  /// Whether [instant] falls in a peak band of Nairobi local time
  /// (UTC+3, no DST): 06:30-09:30 or 16:30-20:00, both inclusive.
  static bool isPeakTime(DateTime instant) {
    final nairobi = instant.toUtc().add(const Duration(hours: 3));
    final minutesOfDay = nairobi.hour * 60 + nairobi.minute;
    return (minutesOfDay >= _peakMorningStart &&
            minutesOfDay <= _peakMorningEnd) ||
        (minutesOfDay >= _peakEveningStart &&
            minutesOfDay <= _peakEveningEnd);
  }

  /// `[low, high]` headway range → "A matatu comes every 5-15 min right now";
  /// anything absent or malformed → [noFrequencyText].
  static String headwayTextForRange(dynamic range) {
    final pair = _rangePair(range);
    if (pair == null) return noFrequencyText;
    return _headwaySentence(pair.$1, pair.$2);
  }

  static String _headwaySentence(num low, num high) {
    if (low == high) {
      return 'A matatu comes every ${_formatNumber(low)} min right now';
    }
    return 'A matatu comes every '
        '${_formatNumber(low)}-${_formatNumber(high)} min right now';
  }

  static String _formatNumber(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  static (num, num)? _rangePair(dynamic range) {
    if (range is! List || range.length != 2) return null;
    final first = range[0];
    final second = range[1];
    if (first is! num || second is! num) return null;
    return (min(first, second), max(first, second));
  }

  static dynamic _chosenRange(Map<String, dynamic> route, DateTime at) =>
      isPeakTime(at)
          ? route['peak_headway_min_range']
          : route['offpeak_headway_min_range'];

  /// Every entry of [routes] that serves the resolved stage, as
  /// `{'route': <route map>, 'directions': [<serving direction maps>]}`.
  static List<Map<String, dynamic>> _servingRoutes({
    required List<dynamic> routes,
    required String stageId,
    required String stageName,
    required List<String> stageRouteNumbers,
  }) {
    final resolved = _resolveStageIds(
      routes: routes,
      stageId: stageId,
      stageName: stageName,
      stageRouteNumbers: stageRouteNumbers,
    );
    if (resolved.isEmpty) return const [];

    final serving = <Map<String, dynamic>>[];
    for (final raw in routes) {
      if (raw is! Map) continue;
      final route = Map<String, dynamic>.from(raw);
      final directions = <Map<String, dynamic>>[];
      for (final rawDirection in (route['directions'] as List? ?? const [])) {
        if (rawDirection is! Map) continue;
        final stages = rawDirection['ordered_stages'] as List? ?? const [];
        if (stages.any((stage) => stage is String && resolved.contains(stage))) {
          directions.add(Map<String, dynamic>.from(rawDirection));
        }
      }
      if (directions.isNotEmpty) {
        serving.add({'route': route, 'directions': directions});
      }
    }
    return serving;
  }

  static Set<String> _resolveStageIds({
    required List<dynamic> routes,
    required String stageId,
    required String stageName,
    required List<String> stageRouteNumbers,
  }) {
    final exactId = _normalize(stageId);
    final core = _nameCore(stageName, fallback: stageId);
    if (exactId.isEmpty && core.isEmpty) return const {};

    final coreWithUnderscores = core;
    final coreWithHyphens = core.replaceAll('_', '-');
    bool matches(String gtfsId) {
      final id = _normalize(gtfsId);
      if (id == exactId || id == core) return true;
      for (final prefix in {coreWithUnderscores, coreWithHyphens}) {
        if (id.startsWith('${prefix}_') || id.startsWith('$prefix-')) {
          return true;
        }
      }
      return false;
    }

    final universe = <String>{};
    final routeNumbersByStage = <String, Set<String>>{};
    for (final raw in routes) {
      if (raw is! Map) continue;
      final number = raw['route_number'];
      if (number is! String) continue;
      for (final rawDirection in (raw['directions'] as List? ?? const [])) {
        if (rawDirection is! Map) continue;
        for (final stage in (rawDirection['ordered_stages'] as List? ?? const [])) {
          if (stage is! String) continue;
          universe.add(stage);
          (routeNumbersByStage[stage] ??= <String>{}).add(number);
        }
      }
    }

    final family = universe.where(matches).toSet();
    if (family.isEmpty || stageRouteNumbers.isEmpty) return family;

    final knownNumbers = stageRouteNumbers.toSet();
    final narrowed = family
        .where((id) =>
            routeNumbersByStage[id]!.intersection(knownNumbers).isNotEmpty)
        .toSet();
    return narrowed.isNotEmpty ? narrowed : family;
  }

  static String _normalize(String value) => value.trim().toLowerCase();

  static String _nameCore(String stageName, {required String fallback}) {
    final words = _normalize(stageName)
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    while (words.isNotEmpty && _genericNameWords.contains(words.last)) {
      words.removeLast();
    }
    if (words.isEmpty) {
      final fallbackWords = _normalize(fallback)
          .split(RegExp(r'[\s_\-]+'))
          .where((word) => word.isNotEmpty && !_genericNameWords.contains(word))
          .toList();
      return fallbackWords.join('_');
    }
    return words.join('_');
  }
}
