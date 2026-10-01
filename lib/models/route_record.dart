class RouteRecord {
  final String routeId;
  final String routeNumber;
  final String routeName;
  final String startStage;
  final String endStage;
  final List<String> orderedStages;
  final double estimatedFare;
  final double peakFare;
  final double offpeakFare;
  final int averageDuration;
  final bool activeStatus;
  final String corridor;
  final String sacco;
  final String? description;
  final double? distance;
  final String trafficLevel;
  final DateTime lastUpdated;

  RouteRecord({
    required this.routeId,
    required this.routeNumber,
    required this.routeName,
    required this.startStage,
    required this.endStage,
    required this.orderedStages,
    this.estimatedFare = 0.0,
    this.peakFare = 0.0,
    this.offpeakFare = 0.0,
    this.averageDuration = 0,
    this.activeStatus = true,
    required this.corridor,
    required this.sacco,
    this.description,
    this.distance,
    this.trafficLevel = 'medium',
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'route_id': routeId,
      'route_number': routeNumber,
      'route_name': routeName,
      'start_stage': startStage,
      'end_stage': endStage,
      'ordered_stages': orderedStages,
      'estimated_fare': estimatedFare,
      'peak_fare': peakFare,
      'offpeak_fare': offpeakFare,
      'average_duration': averageDuration,
      'active_status': activeStatus,
      'corridor': corridor,
      'sacco': sacco,
      'description': description,
      'distance': distance,
      'traffic_level': trafficLevel,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  factory RouteRecord.fromMap(Map<String, dynamic> map, String documentId) {
    return RouteRecord(
      routeId: documentId,
      routeNumber: map['route_number'] ?? map['number'] ?? '',
      routeName: map['route_name'] ?? map['name'] ?? '',
      startStage: map['start_stage'] ?? map['start'] ?? '',
      endStage: map['end_stage'] ?? map['end'] ?? '',
      orderedStages: List<String>.from(
        map['ordered_stages'] ?? map['majorStops'] ?? map['stops'] ?? [],
      ),
      estimatedFare: (map['estimated_fare'] ?? map['baseFare'] ?? 0).toDouble(),
      peakFare: (map['peak_fare'] ?? 0).toDouble(),
      offpeakFare: (map['offpeak_fare'] ?? 0).toDouble(),
      averageDuration: map['average_duration'] ?? map['estimatedTime'] ?? 0,
      activeStatus: map['active_status'] ?? true,
      corridor: map['corridor'] ?? '',
      sacco: map['sacco'] ?? '',
      description: map['description'],
      distance: (map['distance'] as num?)?.toDouble(),
      trafficLevel: map['traffic_level'] ?? map['trafficLevel'] ?? 'medium',
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'])
          : DateTime.now(),
    );
  }

  bool get isActive => activeStatus;

  List<RouteRecord> generateAlternatives() {
    return [];
  }

  RouteRecord copyWith({
    String? routeNumber,
    String? routeName,
    String? startStage,
    String? endStage,
    List<String>? orderedStages,
    double? estimatedFare,
    double? peakFare,
    double? offpeakFare,
    int? averageDuration,
    bool? activeStatus,
    String? trafficLevel,
  }) {
    return RouteRecord(
      routeId: routeId,
      routeNumber: routeNumber ?? this.routeNumber,
      routeName: routeName ?? this.routeName,
      startStage: startStage ?? this.startStage,
      endStage: endStage ?? this.endStage,
      orderedStages: orderedStages ?? this.orderedStages,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      peakFare: peakFare ?? this.peakFare,
      offpeakFare: offpeakFare ?? this.offpeakFare,
      averageDuration: averageDuration ?? this.averageDuration,
      activeStatus: activeStatus ?? this.activeStatus,
      corridor: corridor,
      sacco: sacco,
      description: description,
      distance: distance,
      trafficLevel: trafficLevel ?? this.trafficLevel,
    );
  }
}
