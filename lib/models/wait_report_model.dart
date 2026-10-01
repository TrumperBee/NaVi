class WaitReportModel {
  final String? id;
  final String stageId;
  final String routeId;
  final int waitTime; // in minutes
  final DateTime timestamp;
  final int dayOfWeek;
  final int hourOfDay;
  final String? userId;

  WaitReportModel({
    this.id,
    required this.stageId,
    required this.routeId,
    required this.waitTime,
    required this.timestamp,
    required this.dayOfWeek,
    required this.hourOfDay,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'stage_id': stageId,
      'route_id': routeId,
      'wait_time': waitTime,
      'timestamp': timestamp,
      'day_of_week': dayOfWeek,
      'hour_of_day': hourOfDay,
      'user_id': userId,
    };
  }

  factory WaitReportModel.fromMap(Map<String, dynamic> map, String documentId) {
    return WaitReportModel(
      id: documentId,
      stageId: map['stage_id'] ?? '',
      routeId: map['route_id'] ?? '',
      waitTime: map['wait_time'] ?? 0,
      timestamp: _parseTimestamp(map['timestamp']),
      dayOfWeek: map['day_of_week'] ?? 0,
      hourOfDay: map['hour_of_day'] ?? 0,
      userId: map['user_id'],
    );
  }

  /// Accepts Firestore [Timestamp]s (via `.toDate()`) as well as plain
  /// [DateTime] values (e.g. in tests or cached sources).
  static DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value != null) return (value as dynamic).toDate() as DateTime;
    return DateTime.now();
  }
}