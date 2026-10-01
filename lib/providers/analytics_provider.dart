import 'package:flutter/foundation.dart';
import 'package:navi_app/services/analytics/analytics_service.dart';

class AnalyticsProvider extends ChangeNotifier {
  final AnalyticsService _service = AnalyticsService();

  Map<String, int> _eventCounts = {};
  Map<String, Map<String, int>> _dailyCounts = {};
  bool _isLoading = false;

  Map<String, int> get eventCounts => _eventCounts;
  Map<String, Map<String, int>> get dailyCounts => _dailyCounts;
  bool get isLoading => _isLoading;

  EventTracker track() => _service.track();

  Future<void> loadAnalyticsSummary() async {
    _isLoading = true;
    notifyListeners();

    try {
      _eventCounts = await _service.getEventCounts(since: const Duration(days: 30));
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadDailyTrends(String eventType) async {
    try {
      _dailyCounts[eventType] = await _service.getDailyEventCounts(eventType);
      notifyListeners();
    } catch (_) {}
  }
}
