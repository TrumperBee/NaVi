import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/fare_estimate.dart';

enum SegmentMode { walk, matatu }

class RouteSegment {
  final SegmentMode mode;
  final String label;
  final List<LatLng> coordinates;
  final String? routeNumber;
  final LatLng startPoint;
  final LatLng endPoint;
  final double distanceMeters;
  final Duration estimatedDuration;
  final FareEstimate? fareEstimate;

  const RouteSegment({
    required this.mode,
    required this.label,
    required this.coordinates,
    this.routeNumber,
    required this.startPoint,
    required this.endPoint,
    required this.distanceMeters,
    required this.estimatedDuration,
    this.fareEstimate,
  });

  RouteSegment copyWith({
    SegmentMode? mode,
    String? label,
    List<LatLng>? coordinates,
    String? routeNumber,
    LatLng? startPoint,
    LatLng? endPoint,
    double? distanceMeters,
    Duration? estimatedDuration,
    FareEstimate? fareEstimate,
  }) {
    return RouteSegment(
      mode: mode ?? this.mode,
      label: label ?? this.label,
      coordinates: coordinates ?? this.coordinates,
      routeNumber: routeNumber ?? this.routeNumber,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      fareEstimate: fareEstimate ?? this.fareEstimate,
    );
  }

  factory RouteSegment.walk({
    required String label,
    required List<LatLng> coordinates,
    required LatLng startPoint,
    required LatLng endPoint,
  }) {
    final distance = _calculateDistance(coordinates);
    return RouteSegment(
      mode: SegmentMode.walk,
      label: label,
      coordinates: coordinates,
      routeNumber: null,
      startPoint: startPoint,
      endPoint: endPoint,
      distanceMeters: distance,
      estimatedDuration: Duration(seconds: (distance / 1.4).round()), // 1.4 m/s walking speed
      fareEstimate: null,
    );
  }

  factory RouteSegment.matatu({
    required String label,
    required List<LatLng> coordinates,
    required String routeNumber,
    required LatLng startPoint,
    required LatLng endPoint,
  }) {
    final distance = _calculateDistance(coordinates);
    const double kMatatuAvgSpeedKmh = 20.0;
    final speedMs = kMatatuAvgSpeedKmh * 1000 / 3600;
    return RouteSegment(
      mode: SegmentMode.matatu,
      label: label,
      coordinates: coordinates,
      routeNumber: routeNumber,
      startPoint: startPoint,
      endPoint: endPoint,
      distanceMeters: distance,
      estimatedDuration: Duration(seconds: (distance / speedMs).round()),
      fareEstimate: null,
    );
  }

  static double _calculateDistance(List<LatLng> coordinates) {
    if (coordinates.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < coordinates.length - 1; i++) {
      total += _haversineDistance(
        coordinates[i].latitude,
        coordinates[i].longitude,
        coordinates[i + 1].latitude,
        coordinates[i + 1].longitude,
      );
    }
    return total;
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

  Map<String, dynamic> toGeoJson() {
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': coordinates.map((c) => [c.longitude, c.latitude]).toList(),
      },
      'properties': {
        'mode': mode.name,
        'label': label,
        'routeNumber': routeNumber,
        'distanceMeters': distanceMeters,
        'estimatedDurationSeconds': estimatedDuration.inSeconds,
      },
    };
  }
}