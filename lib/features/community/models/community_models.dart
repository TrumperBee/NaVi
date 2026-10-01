import 'package:latlong2/latlong.dart';

enum SuggestionStatus { pending, approved, rejected, merged }
enum SuggestionType { create, edit, delete }
enum VoteType { upvote, downvote }
enum TrustLevel { newUser, contributor, trusted, moderator, admin }
enum ModerationActionType { warn, suspend, ban, approve, reject }
enum ReportCategory { spam, incorrect, duplicate, abusive }

class CommunityStageSuggestion {
  final String id;
  final SuggestionType type;
  final SuggestionStatus status;
  final String? existingStageId;
  final String name;
  final double latitude;
  final double longitude;
  final String corridor;
  final List<String> routes;
  final String? area;
  final String? notes;
  final String userId;
  final DateTime createdAt;
  final int upvotes;
  final int downvotes;

  CommunityStageSuggestion({
    required this.id,
    required this.type,
    this.status = SuggestionStatus.pending,
    this.existingStageId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.corridor,
    required this.routes,
    this.area,
    this.notes,
    required this.userId,
    DateTime? createdAt,
    this.upvotes = 0,
    this.downvotes = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  LatLng get location => LatLng(latitude, longitude);
  double get score => (upvotes - downvotes).toDouble();

  CommunityStageSuggestion copyWith({
    SuggestionStatus? status,
    int? upvotes,
    int? downvotes,
  }) {
    return CommunityStageSuggestion(
      id: id,
      type: type,
      status: status ?? this.status,
      existingStageId: existingStageId,
      name: name,
      latitude: latitude,
      longitude: longitude,
      corridor: corridor,
      routes: routes,
      area: area,
      notes: notes,
      userId: userId,
      createdAt: createdAt,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'status': status.name,
    'existing_stage_id': existingStageId,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'corridor': corridor,
    'routes': routes,
    'area': area,
    'notes': notes,
    'user_id': userId,
    'created_at': createdAt.toIso8601String(),
    'upvotes': upvotes,
    'downvotes': downvotes,
  };

  factory CommunityStageSuggestion.fromMap(Map<String, dynamic> map, String docId) {
    return CommunityStageSuggestion(
      id: docId,
      type: SuggestionType.values.firstWhere((t) => t.name == map['type']),
      status: SuggestionStatus.values.firstWhere(
        (s) => s.name == map['status'], orElse: () => SuggestionStatus.pending,
      ),
      existingStageId: map['existing_stage_id'],
      name: map['name'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      corridor: map['corridor'] ?? '',
      routes: List<String>.from(map['routes'] ?? []),
      area: map['area'],
      notes: map['notes'],
      userId: map['user_id'] ?? '',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      upvotes: map['upvotes'] ?? 0,
      downvotes: map['downvotes'] ?? 0,
    );
  }
}

class CommunityRouteSuggestion {
  final String id;
  final SuggestionType type;
  final SuggestionStatus status;
  final String? existingRouteId;
  final String number;
  final String name;
  final String corridor;
  final String sacco;
  final List<String> stops;
  final double baseFare;
  final String? notes;
  final String userId;
  final DateTime createdAt;
  final int upvotes;
  final int downvotes;

  CommunityRouteSuggestion({
    required this.id,
    required this.type,
    this.status = SuggestionStatus.pending,
    this.existingRouteId,
    required this.number,
    required this.name,
    required this.corridor,
    required this.sacco,
    required this.stops,
    this.baseFare = 0,
    this.notes,
    required this.userId,
    DateTime? createdAt,
    this.upvotes = 0,
    this.downvotes = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  double get score => (upvotes - downvotes).toDouble();

  CommunityRouteSuggestion copyWith({
    SuggestionStatus? status,
    int? upvotes,
    int? downvotes,
  }) {
    return CommunityRouteSuggestion(
      id: id,
      type: type,
      status: status ?? this.status,
      existingRouteId: existingRouteId,
      number: number,
      name: name,
      corridor: corridor,
      sacco: sacco,
      stops: stops,
      baseFare: baseFare,
      notes: notes,
      userId: userId,
      createdAt: createdAt,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'status': status.name,
    'existing_route_id': existingRouteId,
    'number': number,
    'name': name,
    'corridor': corridor,
    'sacco': sacco,
    'stops': stops,
    'base_fare': baseFare,
    'notes': notes,
    'user_id': userId,
    'created_at': createdAt.toIso8601String(),
    'upvotes': upvotes,
    'downvotes': downvotes,
  };

  factory CommunityRouteSuggestion.fromMap(Map<String, dynamic> map, String docId) {
    return CommunityRouteSuggestion(
      id: docId,
      type: SuggestionType.values.firstWhere((t) => t.name == map['type']),
      status: SuggestionStatus.values.firstWhere(
        (s) => s.name == map['status'], orElse: () => SuggestionStatus.pending,
      ),
      existingRouteId: map['existing_route_id'],
      number: map['number'] ?? '',
      name: map['name'] ?? '',
      corridor: map['corridor'] ?? '',
      sacco: map['sacco'] ?? '',
      stops: List<String>.from(map['stops'] ?? []),
      baseFare: (map['base_fare'] as num?)?.toDouble() ?? 0,
      notes: map['notes'],
      userId: map['user_id'] ?? '',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      upvotes: map['upvotes'] ?? 0,
      downvotes: map['downvotes'] ?? 0,
    );
  }
}

class UserTrustScore {
  final String userId;
  final String userName;
  final TrustLevel level;
  final double score;
  final int reportsSubmitted;
  final int reportsConfirmed;
  final int suggestionsApproved;
  final int verificationsPerformed;
  final int flagsReceived;
  final DateTime lastActive;

  UserTrustScore({
    required this.userId,
    this.userName = 'Anonymous',
    this.level = TrustLevel.newUser,
    this.score = 0,
    this.reportsSubmitted = 0,
    this.reportsConfirmed = 0,
    this.suggestionsApproved = 0,
    this.verificationsPerformed = 0,
    this.flagsReceived = 0,
    DateTime? lastActive,
  }) : lastActive = lastActive ?? DateTime.now();

  double get reliability => reportsSubmitted > 0
      ? reportsConfirmed / reportsSubmitted
      : 0;

  TrustLevel get computedLevel {
    if (flagsReceived > 5) return TrustLevel.newUser;
    if (score >= 1000 && reportsConfirmed > 20) return TrustLevel.admin;
    if (score >= 500 && suggestionsApproved > 5) return TrustLevel.moderator;
    if (score >= 200 && reportsConfirmed > 10) return TrustLevel.trusted;
    if (score >= 50) return TrustLevel.contributor;
    return TrustLevel.newUser;
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'user_name': userName,
    'level': level.name,
    'score': score,
    'reports_submitted': reportsSubmitted,
    'reports_confirmed': reportsConfirmed,
    'suggestions_approved': suggestionsApproved,
    'verifications_performed': verificationsPerformed,
    'flags_received': flagsReceived,
    'last_active': lastActive.toIso8601String(),
  };

  factory UserTrustScore.fromMap(Map<String, dynamic> map, String docId) {
    return UserTrustScore(
      userId: map['user_id'] ?? docId,
      userName: map['user_name'] ?? 'Anonymous',
      level: TrustLevel.values.firstWhere(
        (l) => l.name == map['level'], orElse: () => TrustLevel.newUser,
      ),
      score: (map['score'] as num?)?.toDouble() ?? 0,
      reportsSubmitted: map['reports_submitted'] ?? 0,
      reportsConfirmed: map['reports_confirmed'] ?? 0,
      suggestionsApproved: map['suggestions_approved'] ?? 0,
      verificationsPerformed: map['verifications_performed'] ?? 0,
      flagsReceived: map['flags_received'] ?? 0,
      lastActive: map['last_active'] != null ? DateTime.parse(map['last_active']) : null,
    );
  }
}

class FareIntelligence {
  final String stageId;
  final String stageName;
  final double currentAverage;
  final double previousAverage;
  final double minFare;
  final double maxFare;
  final int reportCount;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<int, double> hourlyAverages;
  final Map<int, double> dailyAverages;
  final double trend; // positive = increasing, negative = decreasing

  FareIntelligence({
    required this.stageId,
    required this.stageName,
    required this.currentAverage,
    required this.previousAverage,
    required this.minFare,
    required this.maxFare,
    required this.reportCount,
    required this.periodStart,
    required this.periodEnd,
    required this.hourlyAverages,
    required this.dailyAverages,
    this.trend = 0,
  });

  double get change => previousAverage > 0
      ? ((currentAverage - previousAverage) / previousAverage) * 100
      : 0;

  String get trendLabel => trend > 5 ? 'rising' : trend < -5 ? 'falling' : 'stable';
}

class TransportHealthMetric {
  final DateTime date;
  final double reliabilityScore;
  final double averageWaitTime;
  final double congestionLevel;
  final int activeReports;
  final int resolvedReports;
  final int totalTrips;
  final double averageFare;
  final double onTimePerformance;
  final List<String> worstRoutes;
  final List<String> bestRoutes;

  TransportHealthMetric({
    required this.date,
    this.reliabilityScore = 0.8,
    this.averageWaitTime = 15,
    this.congestionLevel = 0.5,
    this.activeReports = 0,
    this.resolvedReports = 0,
    this.totalTrips = 0,
    this.averageFare = 60,
    this.onTimePerformance = 0.7,
    this.worstRoutes = const [],
    this.bestRoutes = const [],
  });

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String().substring(0, 10),
    'reliability_score': reliabilityScore,
    'average_wait_time': averageWaitTime,
    'congestion_level': congestionLevel,
    'active_reports': activeReports,
    'resolved_reports': resolvedReports,
    'total_trips': totalTrips,
    'average_fare': averageFare,
    'on_time_performance': onTimePerformance,
    'worst_routes': worstRoutes,
    'best_routes': bestRoutes,
  };

  factory TransportHealthMetric.fromMap(Map<String, dynamic> map) {
    return TransportHealthMetric(
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String().substring(0, 10)),
      reliabilityScore: (map['reliability_score'] as num?)?.toDouble() ?? 0.8,
      averageWaitTime: (map['average_wait_time'] as num?)?.toDouble() ?? 15,
      congestionLevel: (map['congestion_level'] as num?)?.toDouble() ?? 0.5,
      activeReports: map['active_reports'] ?? 0,
      resolvedReports: map['resolved_reports'] ?? 0,
      totalTrips: map['total_trips'] ?? 0,
      averageFare: (map['average_fare'] as num?)?.toDouble() ?? 60,
      onTimePerformance: (map['on_time_performance'] as num?)?.toDouble() ?? 0.7,
      worstRoutes: List<String>.from(map['worst_routes'] ?? []),
      bestRoutes: List<String>.from(map['best_routes'] ?? []),
    );
  }
}

class ModerationRecord {
  final String id;
  final String targetUserId;
  final String targetUserName;
  final ModerationActionType action;
  final String reason;
  final String moderatorId;
  final String moderatorName;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;

  ModerationRecord({
    required this.id,
    required this.targetUserId,
    this.targetUserName = '',
    required this.action,
    required this.reason,
    required this.moderatorId,
    this.moderatorName = '',
    DateTime? createdAt,
    this.expiresAt,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now();
}

class UserReport {
  final String id;
  final String reportedUserId;
  final String reportedUserName;
  final ReportCategory category;
  final String description;
  final String reporterId;
  final String? relatedSuggestionId;
  final DateTime createdAt;
  final bool isResolved;

  UserReport({
    required this.id,
    required this.reportedUserId,
    this.reportedUserName = '',
    required this.category,
    required this.description,
    required this.reporterId,
    this.relatedSuggestionId,
    DateTime? createdAt,
    this.isResolved = false,
  }) : createdAt = createdAt ?? DateTime.now();
}
