import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _settingsBox = 'settings';
  static const String _favoritesBox = 'favorites';
  static const String _recentSearchesBox = 'recent_searches';
  static const String _onboardingBox = 'onboarding';

  Box? _settings;
  Box? _favorites;
  Box? _recentSearches;
  Box? _onboarding;

  Future<void> init() async {
    await Hive.initFlutter();
    _settings = await Hive.openBox(_settingsBox);
    _favorites = await Hive.openBox(_favoritesBox);
    _recentSearches = await Hive.openBox(_recentSearchesBox);
    _onboarding = await Hive.openBox(_onboardingBox);
  }

  // ==================== SETTINGS ====================

  bool getSetting(String key, {bool defaultValue = false}) {
    final value = _settings?.get(key, defaultValue: defaultValue);
    if (value is bool) return value;
    return defaultValue;
  }

  String getStringSetting(String key, {String defaultValue = ''}) {
    final value = _settings?.get(key, defaultValue: defaultValue);
    if (value is String) return value;
    return defaultValue;
  }

  double getDoubleSetting(String key, {double defaultValue = 0.0}) {
    final value = _settings?.get(key, defaultValue: defaultValue);
    if (value is double) return value;
    return defaultValue;
  }

  int getIntSetting(String key, {int defaultValue = 0}) {
    final value = _settings?.get(key, defaultValue: defaultValue);
    if (value is int) return value;
    return defaultValue;
  }

  Future<void> setSetting(String key, dynamic value) async {
    await _settings?.put(key, value);
  }

  Future<void> setStringSetting(String key, String value) async {
    await _settings?.put(key, value);
  }

  // ==================== THEME ====================

  bool get isDarkTheme => getSetting('is_dark_theme');
  Future<void> setDarkTheme(bool value) => setSetting('is_dark_theme', value);

  // ==================== PREFERENCES ====================

  bool get notificationsEnabled => getSetting('notifications_enabled', defaultValue: true);
  Future<void> setNotificationsEnabled(bool value) => setSetting('notifications_enabled', value);

  bool get locationSharingEnabled => getSetting('location_sharing_enabled', defaultValue: true);
  Future<void> setLocationSharingEnabled(bool value) => setSetting('location_sharing_enabled', value);

  String get defaultNavigationMode => getStringSetting('default_navigation_mode', defaultValue: 'transport');
  Future<void> setDefaultNavigationMode(String value) => setStringSetting('default_navigation_mode', value);

  String get routePreference => getStringSetting('route_preference', defaultValue: 'time');
  Future<void> setRoutePreference(String value) => setStringSetting('route_preference', value);

  String get language => getStringSetting('language', defaultValue: 'en');
  Future<void> setLanguage(String value) => setStringSetting('language', value);

  bool get offlineModeEnabled => getSetting('offline_mode_enabled');
  Future<void> setOfflineModeEnabled(bool value) => setSetting('offline_mode_enabled', value);

  // ==================== NAVIGATION PREFERENCES ====================

  bool get avoidBusyJunctions => getSetting('avoid_busy_junctions');
  Future<void> setAvoidBusyJunctions(bool value) => setSetting('avoid_busy_junctions', value);

  bool get preferWalkingPaths => getSetting('prefer_walking_paths');
  Future<void> setPreferWalkingPaths(bool value) => setSetting('prefer_walking_paths', value);

  bool get highAccuracyMode => getSetting('high_accuracy_mode', defaultValue: true);
  Future<void> setHighAccuracyMode(bool value) => setSetting('high_accuracy_mode', value);

  String get distanceUnit => getStringSetting('distance_unit', defaultValue: 'km');
  Future<void> setDistanceUnit(String value) => setStringSetting('distance_unit', value);

  bool get voiceGuidanceEnabled => getSetting('voice_guidance_enabled', defaultValue: true);
  Future<void> setVoiceGuidanceEnabled(bool value) => setSetting('voice_guidance_enabled', value);

  // ==================== STATISTICS ====================

  int get reportsSubmitted => getIntSetting('reports_submitted');
  Future<void> setReportsSubmitted(int value) => setSetting('reports_submitted', value);
  Future<void> incrementReportsSubmitted() async {
    final current = reportsSubmitted;
    await setSetting('reports_submitted', current + 1);
  }

  double get totalKmTraveled => getDoubleSetting('total_km_traveled');
  Future<void> setTotalKmTraveled(double value) => setSetting('total_km_traveled', value);

  int get completedJourneys => getIntSetting('completed_journeys');
  Future<void> setCompletedJourneys(int value) => setSetting('completed_journeys', value);
  Future<void> incrementCompletedJourneys() async {
    await setSetting('completed_journeys', completedJourneys + 1);
  }

  int get totalContributions => getIntSetting('total_contributions');
  Future<void> setTotalContributions(int value) => setSetting('total_contributions', value);

  // ==================== FAVORITES ====================

  Future<List<String>> getFavorites() async {
    final ids = _favorites?.get('stage_ids');
    if (ids is List) return ids.cast<String>();
    return [];
  }

  Future<void> addFavorite(String stageId) async {
    final favorites = await getFavorites();
    if (!favorites.contains(stageId)) {
      favorites.add(stageId);
      await _favorites?.put('stage_ids', favorites);
    }
  }

  Future<void> removeFavorite(String stageId) async {
    final favorites = await getFavorites();
    favorites.remove(stageId);
    await _favorites?.put('stage_ids', favorites);
  }

  Future<bool> isFavorite(String stageId) async {
    final favorites = await getFavorites();
    return favorites.contains(stageId);
  }

  // ==================== RECENT SEARCHES ====================

  Future<List<String>> getRecentSearches({int limit = 10}) async {
    final searches = _recentSearches?.get('searches');
    if (searches is List) return searches.cast<String>().take(limit).toList();
    return [];
  }

  Future<void> addRecentSearch(String query) async {
    final searches = await getRecentSearches();
    searches.remove(query);
    searches.insert(0, query);
    if (searches.length > 20) {
      searches.removeRange(20, searches.length);
    }
    await _recentSearches?.put('searches', searches);
  }

  Future<void> clearRecentSearches() async {
    await _recentSearches?.delete('searches');
  }

  // ==================== ONBOARDING ====================

  bool get hasCompletedOnboarding => getSetting('onboarding_complete', defaultValue: false);
  Future<void> setOnboardingComplete() => setSetting('onboarding_complete', true);

  // ==================== CLEAR ALL ====================

  Future<void> clearAll() async {
    await _settings?.clear();
    await _favorites?.clear();
    await _recentSearches?.clear();
    await _onboarding?.clear();
  }
}
