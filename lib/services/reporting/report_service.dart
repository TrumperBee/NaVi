import 'package:flutter/foundation.dart';
import 'package:navi_app/services/database/database_service.dart';
import 'package:navi_app/utils/geo_utils.dart';

enum ReportType {
  traffic,
  accident,
  congestion,
  fareChange,
  disruption,
  waitTime,
  roadClosure,
  policeCheckpoint,
}

class Report {
  final String id;
  final ReportType type;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String? stageId;
  final String? routeId;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final DateTime expiresAt;
  final int confirmations;
  final int rejections;
  final ReportStatus status;
  final bool isVerified;
  final List<String> mediaUrls;
  final String? additionalInfo;

  Report({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.stageId,
    this.routeId,
    required this.userId,
    this.userName = 'Anonymous',
    DateTime? timestamp,
    DateTime? expiresAt,
    this.confirmations = 0,
    this.rejections = 0,
    this.status = ReportStatus.active,
    this.isVerified = false,
    this.mediaUrls = const [],
    this.additionalInfo,
  })  : timestamp = timestamp ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(hours: 2));

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get needsMoreConfirmations => confirmations < 3;

  Report copyWith({
    int? confirmations,
    int? rejections,
    ReportStatus? status,
  }) {
    return Report(
      id: id,
      type: type,
      title: title,
      description: description,
      latitude: latitude,
      longitude: longitude,
      stageId: stageId,
      routeId: routeId,
      userId: userId,
      userName: userName,
      timestamp: timestamp,
      expiresAt: expiresAt,
      confirmations: confirmations ?? this.confirmations,
      rejections: rejections ?? this.rejections,
      status: status ?? this.status,
      isVerified: isVerified,
      mediaUrls: mediaUrls,
      additionalInfo: additionalInfo,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'stage_id': stageId,
    'route_id': routeId,
    'user_id': userId,
    'user_name': userName,
    'timestamp': timestamp.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'confirmations': confirmations,
    'rejections': rejections,
    'status': status.name,
    'is_verified': isVerified,
    'media_urls': mediaUrls,
    'additional_info': additionalInfo,
  };

  factory Report.fromMap(Map<String, dynamic> map, String docId) => Report(
    id: docId,
    type: ReportType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => ReportType.traffic,
    ),
    title: map['title'] ?? '',
    description: map['description'] ?? '',
    latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    stageId: map['stage_id'],
    routeId: map['route_id'],
    userId: map['user_id'],
    userName: map['user_name'] ?? 'Anonymous',
    timestamp: map['timestamp'] != null
        ? DateTime.parse(map['timestamp'])
        : DateTime.now(),
    expiresAt: map['expires_at'] != null
        ? DateTime.parse(map['expires_at'])
        : DateTime.now().add(const Duration(hours: 2)),
    confirmations: map['confirmations'] ?? 0,
    rejections: map['rejections'] ?? 0,
    status: ReportStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => ReportStatus.active,
    ),
    isVerified: map['is_verified'] ?? false,
    mediaUrls: List<String>.from(map['media_urls'] ?? []),
    additionalInfo: map['additional_info'],
  );
}

enum ReportStatus { active, confirmed, disputed, expired, resolved }

class ReportService extends ChangeNotifier {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final DatabaseService _db = DatabaseService();
  final List<Report> _activeReports = [];

  List<Report> get activeReports => List.unmodifiable(_activeReports);

  List<Report> getReportsNearby(double lat, double lng, {double radiusKm = 2.0}) {
    return _activeReports.where((report) {
      if (report.isExpired) return false;
      final distance = haversineDistance(lat, lng, report.latitude, report.longitude);
      return distance <= radiusKm * 1000;
    }).toList();
  }

  List<Report> getReportsByRoute(String routeId) {
    return _activeReports.where((r) =>
        r.routeId == routeId && !r.isExpired
    ).toList();
  }

  List<Report> getReportsByStage(String stageId) {
    return _activeReports.where((r) =>
        r.stageId == stageId && !r.isExpired
    ).toList();
  }

  List<Report> getReportsByType(ReportType type) {
    return _activeReports.where((r) =>
        r.type == type && !r.isExpired
    ).toList();
  }

  Future<void> submitReport(Report report) async {
    _activeReports.add(report);
    notifyListeners();

    try {
      await _db.saveReport(report.toMap());
    } catch (_) {}
  }

  Future<void> confirmReport(String reportId) async {
    final idx = _activeReports.indexWhere((r) => r.id == reportId);
    if (idx == -1) return;

    final report = _activeReports[idx];
    final updated = report.copyWith(confirmations: report.confirmations + 1);
    _activeReports[idx] = updated;

    if (updated.confirmations >= 3 && !updated.isVerified) {
      _activeReports[idx] = updated.copyWith(
        status: ReportStatus.confirmed,
        confirmations: updated.confirmations,
      );
    }

    notifyListeners();
    await _db.updateReport(reportId, {
      'confirmations': updated.confirmations,
      'status': _activeReports[idx].status.name,
    });
  }

  Future<void> rejectReport(String reportId) async {
    final idx = _activeReports.indexWhere((r) => r.id == reportId);
    if (idx == -1) return;

    final report = _activeReports[idx];
    _activeReports[idx] = report.copyWith(
      rejections: report.rejections + 1,
    );
    notifyListeners();

    await _db.updateReport(reportId, {
      'rejections': report.rejections + 1,
    });
  }

  Future<void> expireOldReports() async {
    _activeReports.removeWhere((r) => r.isExpired);
    notifyListeners();
  }

  Future<void> loadActiveReports() async {
    try {
      final data = await _db.getActiveReports();
      _activeReports.clear();
      for (final entry in data) {
        _activeReports.add(Report.fromMap(entry['data'], entry['id']));
      }
      _activeReports.removeWhere((r) => r.isExpired);
      notifyListeners();
    } catch (_) {}
  }


}
