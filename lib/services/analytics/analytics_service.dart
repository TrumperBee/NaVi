import 'dart:collection';
import 'package:navi_app/services/database/database_service.dart';
import 'package:navi_app/services/database/cache_manager.dart';

class AnalyticsEvent {
  final String type;
  final Map<String, dynamic> properties;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.type,
    this.properties = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'type': type,
    'properties': properties,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AnalyticsEvent.fromMap(Map<String, dynamic> map) => AnalyticsEvent(
    type: map['type'],
    properties: Map<String, dynamic>.from(map['properties'] ?? {}),
    timestamp: map['timestamp'] != null
        ? DateTime.parse(map['timestamp'])
        : DateTime.now(),
  );
}

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final DatabaseService _db = DatabaseService();
  final CacheManager _cache = CacheManager();
  final Queue<AnalyticsEvent> _eventQueue = Queue();
  bool _isFlushing = false;

  static const _batchSize = 20;
  static const _flushInterval = Duration(seconds: 30);

  void init() {
    Future.delayed(_flushInterval, _flush);
  }

  EventTracker track() => EventTracker(this);

  void _enqueue(AnalyticsEvent event) {
    _eventQueue.add(event);
    if (_eventQueue.length >= _batchSize) {
      _flush();
    }
  }

  Future<void> _flush() async {
    if (_isFlushing || _eventQueue.isEmpty) return;
    _isFlushing = true;

    final batch = <AnalyticsEvent>[];
    while (batch.length < _batchSize && _eventQueue.isNotEmpty) {
      batch.add(_eventQueue.removeFirst());
    }

    try {
      await _db.saveAnalyticsBatch(
        batch.map((e) => e.toMap()).toList(),
      );
      _cache.cacheAnalytics(batch);
    } catch (_) {
      for (final event in batch) {
        _eventQueue.addFirst(event);
      }
    } finally {
      _isFlushing = false;
    }

    if (_eventQueue.isNotEmpty) {
      Future.delayed(const Duration(seconds: 5), _flush);
    }
  }

  Future<List<AnalyticsEvent>> getRecentEvents({String? type, int limit = 100}) async {
    try {
      final events = await _db.getRecentAnalytics(type: type, limit: limit);
      return events.map((map) => AnalyticsEvent.fromMap(map)).toList();
    } catch (_) {
      return _cache.getCachedAnalytics().map(
        (map) => AnalyticsEvent.fromMap(map),
      ).toList();
    }
  }

  Future<Map<String, int>> getEventCounts({Duration? since}) async {
    final events = await getRecentEvents(limit: 1000);
    final sinceTime = since != null
        ? DateTime.now().subtract(since)
        : DateTime.fromMillisecondsSinceEpoch(0);

    final counts = <String, int>{};
    for (final event in events) {
      if (event.timestamp.isAfter(sinceTime)) {
        counts[event.type] = (counts[event.type] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<Map<String, int>> getDailyEventCounts(String type) async {
    final events = await getRecentEvents(type: type, limit: 500);
    final daily = <String, int>{};
    for (final event in events) {
      final day = event.timestamp.toIso8601String().substring(0, 10);
      daily[day] = (daily[day] ?? 0) + 1;
    }
    return daily;
  }
}

class EventTracker {
  final AnalyticsService _service;
  final Map<String, dynamic> _properties = {};

  EventTracker(this._service);

  EventTracker withProperty(String key, dynamic value) {
    _properties[key] = value;
    return this;
  }

  void log(String type) {
    _service._enqueue(AnalyticsEvent(
      type: type,
      properties: Map.from(_properties),
    ));
  }

  void search(String query, {int? resultCount}) {
    withProperty('query', query);
    if (resultCount != null) withProperty('result_count', resultCount);
    log('search');
  }

  void routeViewed(String routeId, String routeNumber) {
    withProperty('route_id', routeId);
    withProperty('route_number', routeNumber);
    log('route_view');
  }

  void navigationStarted({
    required String fromStage,
    required String toStage,
    required String routeId,
    double? estimatedFare,
    int? estimatedDuration,
  }) {
    withProperty('from_stage', fromStage);
    withProperty('to_stage', toStage);
    withProperty('route_id', routeId);
    if (estimatedFare != null) withProperty('estimated_fare', estimatedFare);
    if (estimatedDuration != null) withProperty('estimated_duration', estimatedDuration);
    log('navigation_start');
  }

  void navigationCompleted({
    required String fromStage,
    required String toStage,
    required int durationSeconds,
    required double fare,
  }) {
    withProperty('from_stage', fromStage);
    withProperty('to_stage', toStage);
    withProperty('duration_seconds', durationSeconds);
    withProperty('fare', fare);
    log('navigation_complete');
  }

  void reportSubmitted(String reportType) {
    withProperty('report_type', reportType);
    log('report_submit');
  }

  void stageSelected(String stageId, String stageName) {
    withProperty('stage_id', stageId);
    withProperty('stage_name', stageName);
    log('stage_select');
  }

  void peakHourObserved(int hour) {
    withProperty('hour', hour);
    log('peak_hour');
  }

  void error(String message, {String? context}) {
    withProperty('message', message);
    if (context != null) withProperty('context', context);
    log('error');
  }
}
