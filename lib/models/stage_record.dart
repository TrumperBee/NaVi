class StageRecord {
  final String stageId;
  final String stageName;
  final double latitude;
  final double longitude;
  final String roadName;
  final String area;
  final String county;
  final List<String> routesServed;
  final double popularityScore;
  final DateTime lastUpdated;

  StageRecord({
    required this.stageId,
    required this.stageName,
    required this.latitude,
    required this.longitude,
    required this.roadName,
    required this.area,
    required this.county,
    required this.routesServed,
    this.popularityScore = 0.0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'stage_id': stageId,
      'stage_name': stageName,
      'latitude': latitude,
      'longitude': longitude,
      'road_name': roadName,
      'area': area,
      'county': county,
      'routes_served': routesServed,
      'popularity_score': popularityScore,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  factory StageRecord.fromMap(Map<String, dynamic> map, String documentId) {
    return StageRecord(
      stageId: documentId,
      stageName: map['stage_name'] ?? map['name'] ?? '',
      latitude: (map['latitude'] ?? map['lat'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? map['lng'] ?? 0.0).toDouble(),
      roadName: map['road_name'] ?? map['corridor'] ?? '',
      area: map['area'] ?? '',
      county: map['county'] ?? 'Nairobi',
      routesServed: List<String>.from(map['routes_served'] ?? map['routes'] ?? []),
      popularityScore: (map['popularity_score'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'])
          : DateTime.now(),
    );
  }

  factory StageRecord.fromFirestore(Map<String, dynamic> map, String docId) {
    return StageRecord(
      stageId: docId,
      stageName: map['name'] ?? map['stage_name'] ?? '',
      latitude: (map['lat'] ?? map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['lng'] ?? map['longitude'] ?? 0.0).toDouble(),
      roadName: map['road_name'] ?? map['corridor'] ?? '',
      area: map['area'] ?? '',
      county: map['county'] ?? 'Nairobi',
      routesServed: List<String>.from(map['routes'] ?? map['routes_served'] ?? []),
      popularityScore: (map['popularity_score'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: map['last_updated'] != null
          ? (map['last_updated'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  StageRecord copyWith({
    String? stageName,
    double? latitude,
    double? longitude,
    String? roadName,
    String? area,
    String? county,
    List<String>? routesServed,
    double? popularityScore,
    DateTime? lastUpdated,
  }) {
    return StageRecord(
      stageId: stageId,
      stageName: stageName ?? this.stageName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      roadName: roadName ?? this.roadName,
      area: area ?? this.area,
      county: county ?? this.county,
      routesServed: routesServed ?? this.routesServed,
      popularityScore: popularityScore ?? this.popularityScore,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
