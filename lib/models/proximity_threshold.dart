import 'package:navi_app/utils/distance_formatter.dart';

enum ProximityDistance {
  oneKm(1000),
  fiveHundredM(500),
  oneHundredM(100),
  fiftyM(50);

  const ProximityDistance(this.meters);
  final int meters;
}

class ProximityThresholdState {
  final ProximityDistance distance;
  final int meters;
  bool hasFired;

  ProximityThresholdState({
    required this.distance,
    required this.meters,
    this.hasFired = false,
  });

  ProximityThresholdState copyWith({bool? hasFired}) {
    return ProximityThresholdState(
      distance: distance,
      meters: meters,
      hasFired: hasFired ?? this.hasFired,
    );
  }
}

class ProximityTarget {
  final String label;
  final double latitude;
  final double longitude;
  final bool isFinalDestination;

  const ProximityTarget({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.isFinalDestination = false,
  });

  static ProximityTarget fromStage(String label, double lat, double lng, {bool isFinal = false}) {
    return ProximityTarget(
      label: label,
      latitude: lat,
      longitude: lng,
      isFinalDestination: isFinal,
    );
  }
}

enum ProximityAlertType {
  proximity,
  arrivalConfirmed,
}

class ProximityAlertEvent {
  final ProximityTarget target;
  final ProximityDistance threshold;
  final ProximityAlertType type;
  final int remainingMeters;

  const ProximityAlertEvent({
    required this.target,
    required this.threshold,
    required this.type,
    required this.remainingMeters,
  });

  String get displayMessage {
    switch (type) {
      case ProximityAlertType.proximity:
        return 'Approaching ${target.label} — ${DistanceFormatter.format(threshold.meters.toDouble())}';
      case ProximityAlertType.arrivalConfirmed:
        return 'You have arrived at ${target.label}';
    }
  }
}