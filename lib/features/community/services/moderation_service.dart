import 'package:flutter/foundation.dart';
import 'package:navi_app/features/community/models/community_models.dart';
import 'package:navi_app/services/database/database_service.dart';
import 'package:navi_app/services/database/local_storage_service.dart';

class ModerationService extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final LocalStorageService _storage = LocalStorageService();

  List<ModerationRecord> _moderationLog = [];
  List<UserReport> _userReports = [];
  bool _isLoading = false;

  List<ModerationRecord> get moderationLog => List.unmodifiable(_moderationLog);
  List<UserReport> get userReports => List.unmodifiable(_userReports);
  List<UserReport> get unresolvedReports =>
      _userReports.where((r) => !r.isResolved).toList();
  bool get isLoading => _isLoading;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final logData = await _db.getCollectionData('moderation_log');
      _moderationLog = logData.map((entry) => ModerationRecord(
        id: entry['id'],
        targetUserId: entry['data']['target_user_id'] ?? '',
        targetUserName: entry['data']['target_user_name'] ?? '',
        action: ModerationActionType.values.firstWhere(
          (a) => a.name == entry['data']['action']),
        reason: entry['data']['reason'] ?? '',
        moderatorId: entry['data']['moderator_id'] ?? '',
        moderatorName: entry['data']['moderator_name'] ?? '',
        createdAt: entry['data']['created_at'] != null
            ? DateTime.parse(entry['data']['created_at'])
            : null,
        expiresAt: entry['data']['expires_at'] != null
            ? DateTime.parse(entry['data']['expires_at'])
            : null,
        isActive: entry['data']['is_active'] ?? true,
      )).toList();

      const reportCategories = ['spam', 'incorrect', 'duplicate', 'abusive'];
      final reportData = await _db.getCollectionData('user_reports');
      _userReports = reportData.map((entry) => UserReport(
        id: entry['id'],
        reportedUserId: entry['data']['reported_user_id'] ?? '',
        reportedUserName: entry['data']['reported_user_name'] ?? '',
        category: ReportCategory.values.firstWhere(
          (c) => c.name == entry['data']['category'],
          orElse: () => ReportCategory.spam,
        ),
        description: entry['data']['description'] ?? '',
        reporterId: entry['data']['reporter_id'] ?? '',
        relatedSuggestionId: entry['data']['related_suggestion_id'],
        createdAt: entry['data']['created_at'] != null
            ? DateTime.parse(entry['data']['created_at'])
            : null,
        isResolved: entry['data']['is_resolved'] ?? false,
      )).toList();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> takeAction({
    required String targetUserId,
    required String targetUserName,
    required ModerationActionType action,
    required String reason,
    required String moderatorId,
    required String moderatorName,
  }) async {
    final record = ModerationRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      action: action,
      reason: reason,
      moderatorId: moderatorId,
      moderatorName: moderatorName,
      expiresAt: action == ModerationActionType.suspend
          ? DateTime.now().add(const Duration(days: 7))
          : action == ModerationActionType.ban
              ? DateTime.now().add(const Duration(days: 365))
              : null,
    );
    _moderationLog.insert(0, record);
    notifyListeners();
    await _db.addDocument('moderation_log', {
      'target_user_id': targetUserId,
      'target_user_name': targetUserName,
      'action': action.name,
      'reason': reason,
      'moderator_id': moderatorId,
      'moderator_name': moderatorName,
      'created_at': record.createdAt.toIso8601String(),
      'expires_at': record.expiresAt?.toIso8601String(),
      'is_active': true,
    });
  }

  Future<void> submitReport(UserReport report) async {
    _userReports.add(report);
    notifyListeners();
    await _db.addDocument('user_reports', {
      'reported_user_id': report.reportedUserId,
      'reported_user_name': report.reportedUserName,
      'category': report.category.name,
      'description': report.description,
      'reporter_id': report.reporterId,
      'related_suggestion_id': report.relatedSuggestionId,
      'created_at': report.createdAt.toIso8601String(),
      'is_resolved': false,
    });
  }

  Future<void> resolveReport(String reportId) async {
    final idx = _userReports.indexWhere((r) => r.id == reportId);
    if (idx == -1) return;
    _userReports[idx] = UserReport(
      id: _userReports[idx].id,
      reportedUserId: _userReports[idx].reportedUserId,
      reportedUserName: _userReports[idx].reportedUserName,
      category: _userReports[idx].category,
      description: _userReports[idx].description,
      reporterId: _userReports[idx].reporterId,
      relatedSuggestionId: _userReports[idx].relatedSuggestionId,
      createdAt: _userReports[idx].createdAt,
      isResolved: true,
    );
    notifyListeners();
    await _db.updateDocument('user_reports', reportId, {'is_resolved': true});
  }
}
