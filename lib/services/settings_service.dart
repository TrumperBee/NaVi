import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navi_app/core/theme.dart';
import 'package:navi_app/models/app_settings.dart';
import 'package:navi_app/models/journey_record.dart';
import 'package:navi_app/services/database/local_storage_service.dart';
import 'package:navi_app/services/location_service.dart';
import 'package:navi_app/services/navigation_service.dart';
import 'package:navi_app/services/proximity_alert_service.dart';
import 'package:navi_app/services/tts_service.dart';
import 'package:navi_app/utils/distance_formatter.dart';

/// Single source of truth for app settings, backed by [SharedPreferences].
///
/// Keys are namespaced with a `navi.settings.` prefix. Legacy values that were
/// previously stored in the Hive settings box (via [LocalStorageService]) are
/// used as defaults on first load so existing users keep their preferences.
class SettingsService extends ChangeNotifier {
  static const String _prefix = 'navi.settings.';

  static const String _kDarkMode = '${_prefix}dark_mode';
  static const String _kNotifications = '${_prefix}notifications_enabled';
  static const String _kLocationSharing = '${_prefix}location_sharing_enabled';
  static const String _kDefaultNavMode = '${_prefix}default_navigation_mode';
  static const String _kRoutePreference = '${_prefix}route_preference';
  static const String _kLanguage = '${_prefix}language';
  static const String _kOfflineMode = '${_prefix}offline_mode_enabled';
  static const String _kReportsSubmitted = '${_prefix}reports_submitted';
  static const String _kAvoidBusyJunctions = '${_prefix}avoid_busy_junctions';
  static const String _kPreferWalkingPaths = '${_prefix}prefer_walking_paths';
  static const String _kHighAccuracyMode = '${_prefix}high_accuracy_mode';
  static const String _kDistanceUnit = '${_prefix}distance_unit';
  static const String _kVoiceGuidance = '${_prefix}voice_guidance_enabled';
  static const String _kTotalKmTraveled = '${_prefix}total_km_traveled';
  static const String _kCompletedJourneys = '${_prefix}completed_journeys';
  static const String _kTotalContributions = '${_prefix}total_contributions';
  static const String _kSpeedUnit = '${_prefix}speed_unit';
  static const String _kJourneyRecords = '${_prefix}journey_records';

  /// Cap on how many completed trips are retained before the oldest are
  /// dropped, keeping the SharedPreferences entry small.
  static const int _kMaxJourneyRecords = 100;

  /// Saved Home / Work / Campus destination keys. These live under a
  /// `navi.places.` namespace (not the settings prefix) because they are
  /// saved locations, each stored as JSON `{"lat":..,"lng":..,"label":".."}`.
  static const String _placesPrefix = 'navi.places.';
  static const String _kPlaceHome = '${_placesPrefix}home';
  static const String _kPlaceWork = '${_placesPrefix}work';
  static const String _kPlaceCampus = '${_placesPrefix}campus';

  SharedPreferences? _prefs;
  final LocalStorageService _storage = LocalStorageService();

  AppSettings _settings = const AppSettings();
  bool _locationSharingEnabled = true;
  String _defaultNavigationMode = 'transport';
  String _routePreference = 'time';
  String _language = 'en';
  bool _offlineModeEnabled = false;
  int _reportsSubmitted = 0;
  double _totalKmTraveled = 0;
  int _completedJourneys = 0;
  int _totalContributions = 0;

  /// Completed trips, newest first. Source of truth for the Profile stats
  /// ("Trips", "Stages") and detailed journey history.
  List<JourneyRecord> _journeyRecords = [];

  /// Saved destinations, keyed by prefs key. Null value slot means unset.
  final Map<String, SavedPlace> _savedPlaces = {
    _kPlaceHome: const SavedPlace.empty(),
    _kPlaceWork: const SavedPlace.empty(),
    _kPlaceCampus: const SavedPlace.empty(),
  };

  // Convenience aliases (kept for callers of the legacy SettingsProvider API)
  bool get isDarkTheme => _settings.darkMode;
  bool get notificationsEnabled => _settings.notificationsEnabled;
  bool get avoidBusyJunctions => _settings.avoidBusyJunctions;
  bool get preferWalkingPaths => _settings.preferWalkingPaths;
  bool get highAccuracyMode => _settings.highAccuracyMode;
  DistanceUnit get distanceUnit => _settings.distanceUnit;
  DistanceUnit get speedUnit => _settings.speedUnit;
  bool get voiceGuidanceEnabled => _settings.voiceGuidanceEnabled;

  bool get locationSharingEnabled => _locationSharingEnabled;
  String get defaultNavigationMode => _defaultNavigationMode;
  String get routePreference => _routePreference;
  String get language => _language;
  bool get offlineModeEnabled => _offlineModeEnabled;
  int get reportsSubmitted => _reportsSubmitted;

  double get totalKmTraveled => _totalKmTraveled;
  int get completedJourneys => _completedJourneys;
  int get totalContributions => _totalContributions;

  /// Completed trips, newest first (read-only view of the internal list).
  List<JourneyRecord> get journeyRecords => List.unmodifiable(_journeyRecords);

  /// Distinct alighting stages visited across all completed trips — the
  /// Profile "Stages" / "contribution" metric.
  int get distinctStages =>
      _journeyRecords.expand((r) => r.stageNames).toSet().length;

  /// Typed snapshot of the core user-editable settings.
  AppSettings get settings => _settings;

  ThemeData get themeData => AppTheme.getTheme(_settings.darkMode);

  bool get _isLoaded => _prefs != null;

  /// Loads persisted settings. Uses legacy Hive values as defaults on first run.
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;

    _settings = AppSettings(
      speedUnit: DistanceUnit.fromName(
        prefs.getString(_kSpeedUnit) ?? _storage.getStringSetting('speed_unit'),
      ),
      distanceUnit: DistanceUnit.fromName(
        prefs.getString(_kDistanceUnit) ?? _storage.distanceUnit,
      ),
      darkMode: _bool(prefs, _kDarkMode, _storage.isDarkTheme),
      avoidBusyJunctions: _bool(
          prefs, _kAvoidBusyJunctions, _storage.avoidBusyJunctions),
      preferWalkingPaths: _bool(
          prefs, _kPreferWalkingPaths, _storage.preferWalkingPaths),
      highAccuracyMode: _bool(
          prefs, _kHighAccuracyMode, _storage.highAccuracyMode),
      voiceGuidanceEnabled: _bool(
          prefs, _kVoiceGuidance, _storage.voiceGuidanceEnabled),
      notificationsEnabled: _bool(
          prefs, _kNotifications, _storage.notificationsEnabled),
    );

    _locationSharingEnabled =
        prefs.getBool(_kLocationSharing) ?? _storage.locationSharingEnabled;
    _defaultNavigationMode = prefs.getString(_kDefaultNavMode) ??
        _storage.defaultNavigationMode;
    _routePreference =
        prefs.getString(_kRoutePreference) ?? _storage.routePreference;
    _language = prefs.getString(_kLanguage) ?? _storage.language;
    _offlineModeEnabled = _bool(prefs, _kOfflineMode, _storage.offlineModeEnabled);
    _reportsSubmitted = prefs.getInt(_kReportsSubmitted) ??
        _storage.reportsSubmitted;
    _totalKmTraveled =
        prefs.getDouble(_kTotalKmTraveled) ?? _storage.totalKmTraveled;
    _completedJourneys = prefs.getInt(_kCompletedJourneys) ??
        _storage.completedJourneys;
    _totalContributions = prefs.getInt(_kTotalContributions) ??
        _storage.totalContributions;

    _journeyRecords = _decodeJourneyRecords(prefs.getStringList(_kJourneyRecords));

    _loadSavedPlace(_kPlaceHome, _storage.getDoubleSetting('fav_home_lat'),
        _storage.getDoubleSetting('fav_home_lng'),
        _storage.getStringSetting('fav_home_name', defaultValue: 'Home'));
    _loadSavedPlace(
        _kPlaceWork,
        _storage.getDoubleSetting('fav_work_lat'),
        _storage.getDoubleSetting('fav_work_lng'),
        _storage.getStringSetting('fav_work_name', defaultValue: 'Work'));
    _loadSavedPlace(
        _kPlaceCampus,
        _storage.getDoubleSetting('fav_campus_lat'),
        _storage.getDoubleSetting('fav_campus_lng'),
        _storage.getStringSetting('fav_campus_name', defaultValue: 'Campus'));

    _syncDependentServices();
    notifyListeners();
  }

  /// Loads one persisted place as JSON, falling back to the legacy Hive
  /// `fav_*` triple of `{lat,lng,name}` so existing users keep their marks.
  void _loadSavedPlace(String key, double legacyLat, double legacyLng,
      String legacyLabel) {
    final raw = _prefs!.getString(key);
    if (raw != null) {
      try {
        _savedPlaces[key] = SavedPlace.fromJson(raw);
        return;
      } catch (_) {
        // Corrupt / legacy JSON → fall through to the Hive migration below.
      }
    }
    if (legacyLat != 0 && legacyLng != 0) {
      _savedPlaces[key] = SavedPlace(
          lat: legacyLat, lng: legacyLng, label: legacyLabel);
      _prefs!.setString(key, _savedPlaces[key]!.toJson());
    } else {
      _savedPlaces[key] = const SavedPlace.empty();
    }
  }

  bool _bool(SharedPreferences prefs, String key, bool legacy) =>
      prefs.getBool(key) ?? legacy;

  /// Decodes persisted journey-record JSON strings, silencing any corrupt
  /// entries so one bad record can never break settings loading.
  List<JourneyRecord> _decodeJourneyRecords(List<String>? rawList) {
    if (rawList == null) return [];
    final records = <JourneyRecord>[];
    for (final raw in rawList) {
      try {
        records.add(JourneyRecord.fromJson(raw));
      } catch (_) {
        // Skip malformed entries; they are pruned on the next write.
      }
    }
    return records;
  }

  void _syncDependentServices() {
    NavigationService().setDistanceUnit(_settings.distanceUnit);
    DistanceFormatter.currentUnit = _settings.distanceUnit;
    TtsService().setVoiceGuidance(_settings.voiceGuidanceEnabled);
    LocationService().setHighAccuracy(_settings.highAccuracyMode);
    ProximityAlertService().alertsEnabled = _settings.notificationsEnabled;
  }

  // ==================== THEME ====================

  void toggleTheme() => setTheme(!_settings.darkMode);

  void setTheme(bool isDark) {
    if (_settings.darkMode == isDark) return;
    _settings = _settings.copyWith(darkMode: isDark);
    _write(_kDarkMode, isDark);
    notifyListeners();
  }

  // ==================== NOTIFICATIONS ====================

  void toggleNotifications() => setNotificationsEnabled(!_settings.notificationsEnabled);

  void setNotificationsEnabled(bool enabled) {
    if (_settings.notificationsEnabled == enabled) return;
    _settings = _settings.copyWith(notificationsEnabled: enabled);
    _write(_kNotifications, enabled);
    ProximityAlertService().alertsEnabled = enabled;
    notifyListeners();
  }

  // ==================== LOCATION SHARING ====================

  void toggleLocationSharing() => setLocationSharingEnabled(!_locationSharingEnabled);

  void setLocationSharingEnabled(bool enabled) {
    if (_locationSharingEnabled == enabled) return;
    _locationSharingEnabled = enabled;
    _write(_kLocationSharing, enabled);
    notifyListeners();
  }

  // ==================== GENERAL STRING PREFERENCES ====================

  void setDefaultNavigationMode(String mode) {
    if (_defaultNavigationMode == mode) return;
    _defaultNavigationMode = mode;
    _write(_kDefaultNavMode, mode);
    notifyListeners();
  }

  void setRoutePreference(String preference) {
    if (_routePreference == preference) return;
    _routePreference = preference;
    _write(_kRoutePreference, preference);
    notifyListeners();
  }

  void setLanguage(String lang) {
    if (_language == lang) return;
    _language = lang;
    _write(_kLanguage, lang);
    notifyListeners();
  }

  void toggleOfflineMode() {
    _offlineModeEnabled = !_offlineModeEnabled;
    _write(_kOfflineMode, _offlineModeEnabled);
    notifyListeners();
  }

  // ==================== NAVIGATION PREFERENCES ====================

  void toggleAvoidBusyJunctions() =>
      setAvoidBusyJunctions(!_settings.avoidBusyJunctions);

  void setAvoidBusyJunctions(bool value) {
    if (_settings.avoidBusyJunctions == value) return;
    _settings = _settings.copyWith(avoidBusyJunctions: value);
    _write(_kAvoidBusyJunctions, value);
    notifyListeners();
  }

  void togglePreferWalkingPaths() =>
      setPreferWalkingPaths(!_settings.preferWalkingPaths);

  void setPreferWalkingPaths(bool value) {
    if (_settings.preferWalkingPaths == value) return;
    _settings = _settings.copyWith(preferWalkingPaths: value);
    _write(_kPreferWalkingPaths, value);
    notifyListeners();
  }

  void toggleHighAccuracyMode() =>
      setHighAccuracyMode(!_settings.highAccuracyMode);

  void setHighAccuracyMode(bool value) {
    if (_settings.highAccuracyMode == value) return;
    _settings = _settings.copyWith(highAccuracyMode: value);
    _write(_kHighAccuracyMode, value);
    LocationService().setHighAccuracy(value);
    notifyListeners();
  }

  void setDistanceUnit(DistanceUnit unit) {
    if (_settings.distanceUnit == unit) return;
    _settings = _settings.copyWith(distanceUnit: unit);
    _write(_kDistanceUnit, unit.name);
    DistanceFormatter.currentUnit = unit;
    NavigationService().setDistanceUnit(unit);
    notifyListeners();
  }

  void setSpeedUnit(DistanceUnit unit) {
    if (_settings.speedUnit == unit) return;
    _settings = _settings.copyWith(speedUnit: unit);
    _write(_kSpeedUnit, unit.name);
    notifyListeners();
  }

  void toggleVoiceGuidance() =>
      setVoiceGuidanceEnabled(!_settings.voiceGuidanceEnabled);

  void setVoiceGuidanceEnabled(bool value) {
    if (_settings.voiceGuidanceEnabled == value) return;
    _settings = _settings.copyWith(voiceGuidanceEnabled: value);
    _write(_kVoiceGuidance, value);
    TtsService().setVoiceGuidance(value);
    notifyListeners();
  }

  // ==================== STATISTICS ====================

  void incrementReportsSubmitted() {
    _reportsSubmitted++;
    _write(_kReportsSubmitted, _reportsSubmitted);
    notifyListeners();
  }

  void recordJourneyCompletion(double kmTraveled) {
    _completedJourneys++;
    _totalKmTraveled += kmTraveled;
    _write(_kCompletedJourneys, _completedJourneys);
    _write(_kTotalKmTraveled, _totalKmTraveled);
    notifyListeners();
  }

  void incrementContributions() {
    _totalContributions++;
    _write(_kTotalContributions, _totalContributions);
    notifyListeners();
  }

  /// Persists a completed trip (newest first), keeping the aggregate
  /// counters ([completedJourneys], [totalKmTraveled]) in sync so legacy
  /// analytics and the Settings stats card never disagree with the history.
  Future<void> addJourneyRecord(JourneyRecord record) async {
    _journeyRecords.insert(0, record);
    if (_journeyRecords.length > _kMaxJourneyRecords) {
      _journeyRecords =
          _journeyRecords.sublist(0, _kMaxJourneyRecords);
    }
    recordJourneyCompletion(record.distanceKm);
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setStringList(
        _kJourneyRecords,
        [for (final r in _journeyRecords) r.toJson()],
      );
    }
    notifyListeners();
  }

  // ==================== SAVED PLACES (HOME/WORK/CAMPUS) ====================

  static const Map<SavedPlaceKind, String> _placeKindKeys = {
    SavedPlaceKind.home: _kPlaceHome,
    SavedPlaceKind.work: _kPlaceWork,
    SavedPlaceKind.campus: _kPlaceCampus,
  };

  /// The saved coordinate + label for a Home / Work / Campus marked place, or
  /// null when that place has never been set.
  SavedPlace? savedPlace(SavedPlaceKind kind) {
    final stored = _savedPlaces[_placeKindKeys[kind]];
    return (stored == null || stored.isEmpty) ? null : stored;
  }

  /// Persists a saved coordinate + label for Home / Work / Campus as JSON.
  void setSavedPlace(SavedPlaceKind kind, SavedPlace place) {
    final key = _placeKindKeys[kind];
    if (key == null) return;
    _savedPlaces[key] = place;
    _write(key, place.toJson());
    // Keep the legacy Hive keys in sync so the rest of the app's fav_* reads
    // (stage lists, older screens) don't go stale.
    _storage.setSetting('fav_${kind.legacyKey}_lat', place.lat);
    _storage.setSetting('fav_${kind.legacyKey}_lng', place.lng);
    _storage.setStringSetting('fav_${kind.legacyKey}_name', place.label);
    notifyListeners();
  }

  // ==================== DATA MANAGEMENT ====================

  /// Clears journey history, stats, and cached searches.
  Future<void> clearJourneyHistory() async {
    _journeyRecords = [];
    _totalKmTraveled = 0;
    _completedJourneys = 0;
    _totalContributions = 0;
    _reportsSubmitted = 0;
    await _prefs?.remove(_kJourneyRecords);
    await _prefs?.remove(_kTotalKmTraveled);
    await _prefs?.remove(_kCompletedJourneys);
    await _prefs?.remove(_kTotalContributions);
    await _prefs?.remove(_kReportsSubmitted);
    await _storage.clearRecentSearches();
    notifyListeners();
  }

  // ==================== PERSISTENCE HELPERS ====================

  void _write(String key, Object value) {
    if (!_isLoaded) return;
    final prefs = _prefs!;
    if (value is bool) {
      prefs.setBool(key, value);
    } else if (value is int) {
      prefs.setInt(key, value);
    } else if (value is double) {
      prefs.setDouble(key, value);
    } else if (value is String) {
      prefs.setString(key, value);
    } else if (value is List<String>) {
      prefs.setStringList(key, value);
    }
  }
}

/// Which saved place slot a coordinate belongs to. `legacyKey` mirrors the
/// old `fav_home_*` Hive naming so persisted copies stay forward-compatible.
enum SavedPlaceKind {
  home('home'),
  work('work'),
  campus('campus');

  final String legacyKey;
  const SavedPlaceKind(this.legacyKey);
}

/// A saved coordinate + label, persisted as JSON under `navi.places.*`.
class SavedPlace {
  final double lat;
  final double lng;
  final String label;

  const SavedPlace({required this.lat, required this.lng, required this.label});

  const SavedPlace.empty() : this(lat: 0, lng: 0, label: '');

  bool get isEmpty => lat == 0 && lng == 0 && label.isEmpty;

  factory SavedPlace.fromJson(String raw) {
    final data = json.decode(raw) as Map<String, dynamic>;
    return SavedPlace(
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      label: data['label'] as String? ?? '',
    );
  }

  String toJson() => json.encode({
        'lat': lat,
        'lng': lng,
        'label': label,
      });
}