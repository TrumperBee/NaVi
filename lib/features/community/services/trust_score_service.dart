import 'package:flutter/foundation.dart';
import 'package:navi_app/features/community/models/community_models.dart';
import 'package:navi_app/services/database/database_service.dart';
import 'package:navi_app/services/database/local_storage_service.dart';

class TrustScoreService extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final LocalStorageService _storage = LocalStorageService();

  UserTrustScore? _currentScore;
  List<UserTrustScore> _leaderboard = [];

  UserTrustScore? get currentScore => _currentScore;
  List<UserTrustScore> get leaderboard => List.unmodifiable(_leaderboard);

  Future<void> loadScore(String userId) async {
    try {
      final data = await _db.getCollectionData('trust_scores');
      for (final entry in data) {
        final score = UserTrustScore.fromMap(entry['data'], entry['id']);
        if (score.userId == userId) {
          _currentScore = score;
          notifyListeners();
          return;
        }
      }
      _currentScore = UserTrustScore(userId: userId);
      await _db.addDocument('trust_scores', _currentScore!.toMap());
      notifyListeners();
    } catch (_) {}
  }

  Future<void> recordReportSubmitted(String userId) async {
    final score = await _getOrCreateScore(userId);
    final updated = UserTrustScore(
      userId: score.userId,
      userName: score.userName,
      score: score.score + 10,
      reportsSubmitted: score.reportsSubmitted + 1,
      reportsConfirmed: score.reportsConfirmed,
      suggestionsApproved: score.suggestionsApproved,
      verificationsPerformed: score.verificationsPerformed,
      flagsReceived: score.flagsReceived,
      level: score.computedLevel,
    );
    await _saveScore(updated);
  }

  Future<void> recordReportConfirmed(String userId) async {
    final score = await _getOrCreateScore(userId);
    final updated = UserTrustScore(
      userId: score.userId,
      userName: score.userName,
      score: score.score + 25,
      reportsSubmitted: score.reportsSubmitted,
      reportsConfirmed: score.reportsConfirmed + 1,
      suggestionsApproved: score.suggestionsApproved,
      verificationsPerformed: score.verificationsPerformed,
      flagsReceived: score.flagsReceived,
      level: score.computedLevel,
    );
    await _saveScore(updated);
  }

  Future<void> recordSuggestionApproved(String userId) async {
    final score = await _getOrCreateScore(userId);
    final updated = UserTrustScore(
      userId: score.userId,
      userName: score.userName,
      score: score.score + 50,
      reportsSubmitted: score.reportsSubmitted,
      reportsConfirmed: score.reportsConfirmed,
      suggestionsApproved: score.suggestionsApproved + 1,
      verificationsPerformed: score.verificationsPerformed,
      flagsReceived: score.flagsReceived,
      level: score.computedLevel,
    );
    await _saveScore(updated);
  }

  Future<void> recordVerification(String userId) async {
    final score = await _getOrCreateScore(userId);
    final updated = UserTrustScore(
      userId: score.userId,
      userName: score.userName,
      score: score.score + 5,
      reportsSubmitted: score.reportsSubmitted,
      reportsConfirmed: score.reportsConfirmed,
      suggestionsApproved: score.suggestionsApproved,
      verificationsPerformed: score.verificationsPerformed + 1,
      flagsReceived: score.flagsReceived,
      level: score.computedLevel,
    );
    await _saveScore(updated);
  }

  Future<void> recordFlag(String userId) async {
    final score = await _getOrCreateScore(userId);
    final updated = UserTrustScore(
      userId: score.userId,
      userName: score.userName,
      score: (score.score - 20).clamp(0, double.infinity),
      reportsSubmitted: score.reportsSubmitted,
      reportsConfirmed: score.reportsConfirmed,
      suggestionsApproved: score.suggestionsApproved,
      verificationsPerformed: score.verificationsPerformed,
      flagsReceived: score.flagsReceived + 1,
      level: score.computedLevel,
    );
    await _saveScore(updated);
  }

  Future<void> loadLeaderboard() async {
    try {
      final data = await _db.getCollectionData('trust_scores');
      _leaderboard = data.map((entry) =>
          UserTrustScore.fromMap(entry['data'], entry['id'])).toList();
      _leaderboard.sort((a, b) => b.score.compareTo(a.score));
      notifyListeners();
    } catch (_) {}
  }

  bool canModerate(String userId) {
    if (_currentScore == null) return false;
    return _currentScore!.level.index >= TrustLevel.moderator.index;
  }

  Future<UserTrustScore> _getOrCreateScore(String userId) async {
    if (_currentScore != null && _currentScore!.userId == userId) {
      return _currentScore!;
    }
    await loadScore(userId);
    return _currentScore ?? UserTrustScore(userId: userId);
  }

  Future<void> _saveScore(UserTrustScore score) async {
    _currentScore = score;
    try {
      final data = await _db.getCollectionData('trust_scores');
      for (final entry in data) {
        final existing = UserTrustScore.fromMap(entry['data'], entry['id']);
        if (existing.userId == score.userId) {
          await _db.updateDocument('trust_scores', entry['id'], score.toMap());
          notifyListeners();
          return;
        }
      }
      await _db.addDocument('trust_scores', score.toMap());
    } catch (_) {}
    notifyListeners();
  }
}
