import 'package:navi_app/services/database/local_storage_service.dart';

class AntiSpamService {
  final LocalStorageService _storage = LocalStorageService();

  static const int _maxReportsPerHour = 5;
  static const int _maxSuggestionsPerDay = 3;
  static const int _cooldownSeconds = 30;

  final Map<String, List<DateTime>> _reportTimestamps = {};
  final Map<String, List<DateTime>> _suggestionTimestamps = {};
  final Map<String, DateTime> _lastActionTimestamps = {};

  bool canSubmitReport(String userId) {
    final now = DateTime.now();
    final timestamps = _reportTimestamps[userId] ?? [];
    final recent = timestamps.where((t) =>
        now.difference(t).inHours < 1).toList();
    if (recent.length >= _maxReportsPerHour) return false;
    return _checkCooldown(userId);
  }

  bool canSubmitSuggestion(String userId) {
    final now = DateTime.now();
    final timestamps = _suggestionTimestamps[userId] ?? [];
    final recent = timestamps.where((t) =>
        now.difference(t).inDays < 1).toList();
    if (recent.length >= _maxSuggestionsPerDay) return false;
    return _checkCooldown(userId);
  }

  bool _checkCooldown(String userId) {
    final lastAction = _lastActionTimestamps[userId];
    if (lastAction == null) return true;
    return DateTime.now().difference(lastAction).inSeconds >= _cooldownSeconds;
  }

  void recordReport(String userId) {
    _reportTimestamps.putIfAbsent(userId, () => []).add(DateTime.now());
    _lastActionTimestamps[userId] = DateTime.now();
  }

  void recordSuggestion(String userId) {
    _suggestionTimestamps.putIfAbsent(userId, () => []).add(DateTime.now());
    _lastActionTimestamps[userId] = DateTime.now();
  }

  bool isSpamContent(String text) {
    final lower = text.toLowerCase();
    final spamPatterns = [
      RegExp(r'(.)\1{5,}'), r'buy now', r'click here', r'free money',
      r'limited offer', r'act now', r'congratulations',
      r'http[s]?://', r'www\.',
    ];
    for (final pattern in spamPatterns) {
      if (pattern is RegExp && pattern.hasMatch(lower)) return true;
      if (pattern is String && lower.contains(pattern)) return true;
    }
    return false;
  }

  bool isDuplicateContent(String newText, List<String> existingTexts) {
    final normalized = newText.toLowerCase().trim();
    for (final existing in existingTexts) {
      final existingLower = existing.toLowerCase().trim();
      if (_similarity(normalized, existingLower) > 0.8) return true;
    }
    return false;
  }

  double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.length < 3 || b.length < 3) return 0.0;
    final pairsA = _wordPairs(a);
    final pairsB = _wordPairs(b);
    if (pairsA.isEmpty || pairsB.isEmpty) return 0.0;
    int matches = 0;
    for (final pair in pairsA) {
      if (pairsB.contains(pair)) matches++;
    }
    return (2.0 * matches) / (pairsA.length + pairsB.length);
  }

  Set<String> _wordPairs(String s) {
    final pairs = <String>{};
    for (int i = 0; i < s.length - 1; i++) {
      pairs.add(s.substring(i, i + 2));
    }
    return pairs;
  }
}
