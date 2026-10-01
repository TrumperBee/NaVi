import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'route_segment.dart';

class ActiveJourney {
  final List<RouteSegment> segments;
  int currentSegmentIndex;
  LatLng? currentPosition;
  double progressAlongCurrentSegment;

  ActiveJourney({
    required this.segments,
    this.currentSegmentIndex = 0,
    this.currentPosition,
    this.progressAlongCurrentSegment = 0.0,
  });

  RouteSegment? get currentSegment {
    if (segments.isEmpty || currentSegmentIndex >= segments.length) return null;
    return segments[currentSegmentIndex];
  }

  bool get isComplete => currentSegmentIndex >= segments.length;

  double get totalDistanceMeters {
    return segments.fold(0.0, (sum, s) => sum + s.distanceMeters);
  }

  Duration get totalEstimatedDuration {
    return Duration(
      seconds: segments.fold(0, (sum, s) => sum + s.estimatedDuration.inSeconds),
    );
  }

  /// Remaining distance from the current position to the end of the journey
  /// (current segment's leftover plus all future segments).
  double get remainingDistanceMeters {
    if (isComplete) return 0;
    double remaining = 0;
    for (int i = currentSegmentIndex; i < segments.length; i++) {
      final segment = segments[i];
      if (i == currentSegmentIndex) {
        remaining += segment.distanceMeters * (1 - progressAlongCurrentSegment);
      } else {
        remaining += segment.distanceMeters;
      }
    }
    return remaining;
  }

  /// Remaining time from the current position to the end of the journey.
  Duration get remainingDuration {
    if (isComplete) return Duration.zero;
    int seconds = 0;
    for (int i = currentSegmentIndex; i < segments.length; i++) {
      final segment = segments[i];
      if (i == currentSegmentIndex) {
        seconds +=
            (segment.estimatedDuration.inSeconds * (1 - progressAlongCurrentSegment))
                .round();
      } else {
        seconds += segment.estimatedDuration.inSeconds;
      }
    }
    return Duration(seconds: seconds);
  }

  /// Distance of only the walking segments. This is the value surfaced by
  /// both the pre-trip header and the bottom metrics row so the two can never
  /// disagree about how far the user walks.
  double get walkDistanceMeters {
    return segments
        .where((s) => s.mode == SegmentMode.walk)
        .fold(0.0, (sum, s) => sum + s.distanceMeters);
  }

  /// Combined walking time (excludes vehicle legs).
  Duration get walkDuration {
    return Duration(
      seconds: segments
          .where((s) => s.mode == SegmentMode.walk)
          .fold(0, (sum, s) => sum + s.estimatedDuration.inSeconds),
    );
  }

  /// Combined matatu riding time (excludes walking legs).
  Duration get matatuDuration {
    return Duration(
      seconds: segments
          .where((s) => s.mode == SegmentMode.matatu)
          .fold(0, (sum, s) => sum + s.estimatedDuration.inSeconds),
    );
  }

  /// Fare estimate collected from the segments' own fare estimates. Walking
  /// segments contribute 0; matatu segments always contribute from the fare
  /// bracket table, so a matatu-inclusive journey can never total KSh 0.
  int get fareTotalKsh {
    return segments.fold(
        0, (sum, s) => sum + (s.fareEstimate?.amountKsh ?? 0));
  }

  List<RouteSegment> get completedSegments {
    if (currentSegmentIndex == 0) return [];
    return segments.sublist(0, currentSegmentIndex);
  }

  List<RouteSegment> get upcomingSegments {
    if (currentSegmentIndex >= segments.length - 1) return [];
    return segments.sublist(currentSegmentIndex + 1);
  }

  void updatePosition(LatLng position) {
    currentPosition = position;
    _recalculateSegmentAndProgress();
  }

  void _recalculateSegmentAndProgress() {
    if (currentPosition == null || segments.isEmpty) return;

    // Walk forward past any segments whose end we have already reached.
    while (currentSegmentIndex < segments.length) {
      final segment = segments[currentSegmentIndex];
      final distToEnd = _haversineDistance(
        currentPosition!.latitude,
        currentPosition!.longitude,
        segment.endPoint.latitude,
        segment.endPoint.longitude,
      );
      if (distToEnd < 50) {
        currentSegmentIndex += 1;
        progressAlongCurrentSegment = 1.0;
        continue;
      }
      break;
    }

    if (currentSegmentIndex >= segments.length) {
      // Journey complete.
      progressAlongCurrentSegment = 1.0;
      return;
    }

    final segment = segments[currentSegmentIndex];
    final distToEnd = _haversineDistance(
      currentPosition!.latitude,
      currentPosition!.longitude,
      segment.endPoint.latitude,
      segment.endPoint.longitude,
    );
    final segmentLength = segment.distanceMeters < 1.0 ? 1.0 : segment.distanceMeters;
    progressAlongCurrentSegment = (1.0 - distToEnd / segmentLength).clamp(0.0, 1.0);
  }

static double _haversineDistance(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    const double R = 6371000;
    final dLat = (lat2 - lat1) * 3.14159265359 / 180;
    final dLng = (lng2 - lng1) * 3.14159265359 / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * 3.14159265359 / 180) * cos(lat2 * 3.14159265359 / 180) *
        sin(dLng / 2) * sin(dLng / 2);
    return 2 * atan2(sqrt(a), sqrt(1 - a)) * R;
}

  // Get the remaining polyline for the current segment
  List<LatLng> getCurrentSegmentRemainingCoordinates() {
    final segment = currentSegment;
    if (segment == null) return [];

    // Find the index in coordinates closest to current position
    if (currentPosition == null) return segment.coordinates;

    int closestIndex = 0;
    double minDist = double.infinity;
    for (int i = 0; i < segment.coordinates.length; i++) {
      final dist = _haversineDistance(
        currentPosition!.latitude,
        currentPosition!.longitude,
        segment.coordinates[i].latitude,
        segment.coordinates[i].longitude,
      );
      if (dist < minDist) {
        minDist = dist;
        closestIndex = i;
      }
    }

    // Return remaining coordinates (add a small buffer)
    final startIdx = (closestIndex - 2).clamp(0, segment.coordinates.length - 2);
    return segment.coordinates.sublist(startIdx);
  }

  // Get all traveled coordinates (for rendering as dimmed)
  List<LatLng> getTraveledCoordinates() {
    final traveled = <LatLng>[];

    // Add all completed segments
    for (int i = 0; i < currentSegmentIndex; i++) {
      traveled.addAll(segments[i].coordinates);
    }

    // Add traveled portion of current segment
    final current = currentSegment;
    if (current != null && currentPosition != null) {
      int closestIndex = 0;
      double minDist = double.infinity;
      for (int i = 0; i < current.coordinates.length; i++) {
        final dist = _haversineDistance(
          currentPosition!.latitude,
          currentPosition!.longitude,
          current.coordinates[i].latitude,
          current.coordinates[i].longitude,
        );
        if (dist < minDist) {
          minDist = dist;
          closestIndex = i;
        }
      }
      if (closestIndex > 0) {
        traveled.addAll(current.coordinates.sublist(0, closestIndex + 1));
      }
    }

return traveled;
  }
}