import 'dart:convert';

import 'active_journey.dart';
import 'route_segment.dart';

/// A single completed trip, persisted as a JSON object inside a
/// `StringList` shared-preference entry (`navi.settings.journey_records`).
///
/// Written every time a live journey actually completes (the traveller
/// reaches the destination), never when a trip is cancelled mid-way.
class JourneyRecord {
  final DateTime date;
  final String originLabel;
  final String destinationLabel;
  final double distanceKm;
  final int fareKsh;
  final int durationMinutes;

  /// Alighting stage names visited on the matatu legs (used for the Profile
  /// "distinct stages navigated" statistic).
  final List<String> stageNames;

  const JourneyRecord({
    required this.date,
    required this.originLabel,
    required this.destinationLabel,
    required this.distanceKm,
    required this.fareKsh,
    required this.durationMinutes,
    required this.stageNames,
  });

  double get distanceMeters => distanceKm * 1000;

  /// Builds a record from a completed [journey]. Matatu segment labels are
  /// shaped "Ride Route <n> to <stage>" by [RouteBuilderService], so the
  /// alighting stage name is the text after the last " to ".
  factory JourneyRecord.fromJourney(
    ActiveJourney journey, {
    required String originLabel,
    required String destinationLabel,
  }) {
    final stageNames = <String>[];
    for (final segment in journey.segments) {
      if (segment.mode != SegmentMode.matatu) continue;
      final label = segment.label;
      if (!label.startsWith('Ride Route ')) continue;
      final parts = label.split(' to ');
      if (parts.length > 1 && parts.last.trim().isNotEmpty) {
        stageNames.add(parts.last.trim());
      }
    }
    return JourneyRecord(
      date: DateTime.now(),
      originLabel: originLabel.trim().isEmpty
          ? 'Current location'
          : originLabel.trim(),
      destinationLabel: destinationLabel.trim().isEmpty
          ? 'Destination'
          : destinationLabel.trim(),
      distanceKm: journey.totalDistanceMeters / 1000,
      fareKsh: journey.fareTotalKsh,
      durationMinutes: journey.totalEstimatedDuration.inMinutes,
      stageNames: stageNames,
    );
  }

  factory JourneyRecord.fromJson(String raw) {
    final data = Map<String, dynamic>.from(
        (json.decode(raw) as Map).cast<String, dynamic>());
    return JourneyRecord(
      date: DateTime.tryParse(data['date'] as String? ?? '') ?? DateTime.now(),
      originLabel: data['originLabel'] as String? ?? '',
      destinationLabel: data['destinationLabel'] as String? ?? '',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      fareKsh: (data['fareKsh'] as num?)?.toInt() ?? 0,
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
      stageNames: (data['stageNames'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'originLabel': originLabel,
      'destinationLabel': destinationLabel,
      'distanceKm': distanceKm,
      'fareKsh': fareKsh,
      'durationMinutes': durationMinutes,
      'stageNames': stageNames,
    };
  }

  String toJson() => json.encode(toMap());
}