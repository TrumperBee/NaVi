import 'package:latlong2/latlong.dart';

// ==================== BASE NODE ====================
class Node {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String type; // 'stage', 'place', 'landmark'

  Node({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
  });

  LatLng get location => LatLng(lat, lng);
}

// ==================== STAGE MODEL ====================
class StageModel extends Node {
  final String corridor;
  final List<String> routes; // Route numbers that serve this stage
  final List<String>? saccos;
  final String? area;
  double? averageFare;
  int? totalReports;
  Map<String, dynamic>? fareHistory;

  /// Optional link to a named place (spec §1.2), kept on the cached shape so
  /// the one-time GTFS import's place links survive a relaunch. Additive:
  /// cached rows written before this field existed decode to null.
  String? placeId;

  StageModel({
    required super.id,
    required super.name,
    required super.lat,
    required super.lng,
    required this.corridor,
    required this.routes,
    this.saccos,
    this.area,
    this.averageFare,
    this.totalReports,
    this.fareHistory,
    this.placeId,
  }) : super(type: 'stage');

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'corridor': corridor,
      'routes': routes,
      'saccos': saccos,
      'area': area,
      'average_fare': averageFare,
      'total_reports': totalReports,
      'fare_history': fareHistory,
      'place_id': placeId,
    };
  }

  factory StageModel.fromMap(Map<String, dynamic> map, String documentId) {
    return StageModel(
      id: documentId,
      name: map['name'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      corridor: map['corridor'] ?? '',
      routes: List<String>.from(map['routes'] ?? []),
      saccos: map['saccos'] != null ? List<String>.from(map['saccos']) : null,
      area: map['area'],
      averageFare: (map['average_fare'] as num?)?.toDouble(),
      totalReports: map['total_reports'],
      fareHistory: map['fare_history'] as Map<String, dynamic>?,
      placeId: map['place_id'] as String?,
    );
  }
}

// ==================== PLACE MODEL ====================
class PlaceModel extends Node {
  final String category;
  final String? address;
  final Map<String, dynamic>? metadata;

  PlaceModel({
    required super.id,
    required super.name,
    required super.lat,
    required super.lng,
    required this.category,
    this.address,
    this.metadata,
  }) : super(type: 'place');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'category': category,
      'address': address,
      'metadata': metadata,
    };
  }

  factory PlaceModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PlaceModel(
      id: documentId,
      name: map['name'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      category: map['category'] ?? 'other',
      address: map['address'],
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

// ==================== ROUTE MODEL ====================
class RouteModel {
  final String id;
  final String name;
  final String number; 
  final String corridor; 
  final String sacco; 
  final List<String> majorStops; // Changed back to match your seed_data
  final double baseFare;
  final String? description;
  final int? estimatedTime;
  final String? trafficLevel;
  final double? distance;

  RouteModel({
    required this.id,
    required this.name,
    required this.number,
    required this.corridor,
    required this.sacco,
    required this.majorStops,
    this.baseFare = 0.0,
    this.description,
    this.estimatedTime,
    this.trafficLevel,
    this.distance,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'number': number,
      'corridor': corridor,
      'sacco': sacco,
      'majorStops': majorStops,
      'baseFare': baseFare,
      'description': description,
      'estimatedTime': estimatedTime,
      'trafficLevel': trafficLevel,
      'distance': distance,
    };
  }

  factory RouteModel.fromMap(Map<String, dynamic> data, String documentId) {
    return RouteModel(
      id: documentId,
      name: data['name'] ?? '',
      number: data['number'] ?? '',
      corridor: data['corridor'] ?? '',
      sacco: data['sacco'] ?? '',
      // This handles both names if you have them in Firestore
      majorStops: List<String>.from(data['majorStops'] ?? data['stops'] ?? []),
      baseFare: (data['baseFare'] ?? data['base_fare'] ?? 0).toDouble(),
      description: data['description'],
      estimatedTime: data['estimatedTime'] ?? data['estimated_time'],
      trafficLevel: data['trafficLevel'] ?? data['traffic_level'],
      distance: (data['distance'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() {
    return '$number - $name ($sacco)';
  }
}

// ==================== EDGE MODEL ====================
class Edge {
  final String id;
  final Node from;
  final Node to;
  final double distance; // in meters
  final List<String> routeNumbers; // matatu route numbers that use this edge
  final int averageTime; // in seconds
  final double baseFare;
  final String trafficLevel; // 'low', 'medium', 'high'
  final DateTime lastUpdated;

  Edge({
    required this.id,
    required this.from,
    required this.to,
    required this.distance,
    required this.routeNumbers,
    required this.averageTime,
    required this.baseFare,
    required this.trafficLevel,
    required this.lastUpdated,
  });

  // Calculate current time based on traffic
  int get currentTime {
    switch (trafficLevel) {
      case 'high':
        return (averageTime * 1.5).round();
      case 'medium':
        return (averageTime * 1.2).round();
      default:
        return averageTime;
    }
  }

  // Calculate current fare (base + surge if any)
  double get currentFare {
    final now = DateTime.now();
    final hour = now.hour;
    final isPeak = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19);

    if (isPeak && trafficLevel == 'high') {
      return baseFare * 1.2; // 20% surge during peak traffic
    }
    return baseFare;
  }
}

// ==================== PATH OPTION MODEL ====================
class PathOption {
  final List<Node> path;
  final List<Edge> edges;
  final double totalDistance;
  final int totalTime;
  final double totalFare;
  final int transferCount;
  final List<String> routeNumbers;
  final String description;

  PathOption({
    required this.path,
    required this.edges,
    required this.totalDistance,
    required this.totalTime,
    required this.totalFare,
    required this.transferCount,
    required this.routeNumbers,
    required this.description,
  });

  PathOption copyWith({
    List<Node>? path,
    List<Edge>? edges,
    double? totalDistance,
    int? totalTime,
    double? totalFare,
    int? transferCount,
    List<String>? routeNumbers,
    String? description,
  }) {
    return PathOption(
      path: path ?? this.path,
      edges: edges ?? this.edges,
      totalDistance: totalDistance ?? this.totalDistance,
      totalTime: totalTime ?? this.totalTime,
      totalFare: totalFare ?? this.totalFare,
      transferCount: transferCount ?? this.transferCount,
      routeNumbers: routeNumbers ?? this.routeNumbers,
      description: description ?? this.description,
    );
  }

  // Get formatted time string
  String get formattedTime {
    if (totalTime < 60) {
      return '$totalTime sec';
    } else if (totalTime < 3600) {
      int minutes = (totalTime / 60).round();
      return '$minutes min';
    } else {
      int hours = (totalTime / 3600).floor();
      int minutes = ((totalTime % 3600) / 60).round();
      return '$hours hr $minutes min';
    }
  }

  // Get formatted distance string
  String get formattedDistance {
    if (totalDistance < 1000) {
      return '${totalDistance.round()} m';
    } else {
      return '${(totalDistance / 1000).toStringAsFixed(1)} km';
    }
  }

  // Get formatted fare string
  String get formattedFare {
    return 'KSh ${totalFare.toStringAsFixed(0)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'path_ids': path.map((n) => n.id).toList(),
      'edge_ids': edges.map((e) => e.id).toList(),
      'total_distance': totalDistance,
      'total_time': totalTime,
      'total_fare': totalFare,
      'transfer_count': transferCount,
      'route_numbers': routeNumbers,
      'description': description,
    };
  }
}

// ==================== TRANSPORT ANALYTICS ====================
class TransportAnalytics {
  final String userId;
  final DateTime month;
  final double totalSpent;
  final double totalDistance;
  final int totalTrips;
  final Map<String, int> routeFrequency;
  final Map<String, double> dailySpending;
  final List<Map<String, dynamic>> tripHistory;

  TransportAnalytics({
    required this.userId,
    required this.month,
    required this.totalSpent,
    required this.totalDistance,
    required this.totalTrips,
    required this.routeFrequency,
    required this.dailySpending,
    required this.tripHistory,
  });

  // Get most used route
  String? get mostUsedRoute {
    if (routeFrequency.isEmpty) return null;
    return routeFrequency.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // Get average fare per trip
  double get averageFare => totalTrips > 0 ? totalSpent / totalTrips : 0;

  // Get average distance per trip
  double get averageDistance => totalTrips > 0 ? totalDistance / totalTrips : 0;

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'month': month.toIso8601String(),
      'total_spent': totalSpent,
      'total_distance': totalDistance,
      'total_trips': totalTrips,
      'route_frequency': routeFrequency,
      'daily_spending': dailySpending,
      'trip_history': tripHistory,
    };
  }

  factory TransportAnalytics.fromMap(Map<String, dynamic> map, String documentId) {
    return TransportAnalytics(
      userId: map['user_id'] ?? '',
      month: DateTime.parse(map['month']),
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0,
      totalDistance: (map['total_distance'] as num?)?.toDouble() ?? 0,
      totalTrips: map['total_trips'] ?? 0,
      routeFrequency: Map<String, int>.from(map['route_frequency'] ?? {}),
      dailySpending: Map<String, double>.from(map['daily_spending'] ?? {}),
      tripHistory: List<Map<String, dynamic>>.from(map['trip_history'] ?? []),
    );
  }
}

// ==================== INSTRUCTION STEP ====================
class InstructionStep {
  final String instruction;
  final double distance;
  final int duration;
  final String type; // 'walk', 'board', 'alight', 'transfer'
  final String? icon;
  final Node? startNode;
  final Node? endNode;
  final String? routeNumber;

  InstructionStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.type,
    this.icon,
    this.startNode,
    this.endNode,
    this.routeNumber,
  });

  String get formattedDistance {
    if (distance < 1000) {
      return '${distance.round()} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  String get formattedDuration {
    if (duration < 60) {
      return '$duration sec';
    } else if (duration < 3600) {
      int minutes = (duration / 60).round();
      return '$minutes min';
    } else {
      int hours = (duration / 3600).floor();
      int minutes = ((duration % 3600) / 60).round();
      return '$hours hr $minutes min';
    }
  }
}