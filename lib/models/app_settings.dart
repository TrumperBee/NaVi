/// Distance display unit preference.
enum DistanceUnit {
  km,
  mi;

  static DistanceUnit fromName(String? name) {
    return DistanceUnit.values.firstWhere(
      (unit) => unit.name == name,
      orElse: () => DistanceUnit.km,
    );
  }
}

/// Map style preference.
enum MapStyle {
  day,
  night;

  static MapStyle fromName(String? name) {
    return MapStyle.values.firstWhere(
      (style) => style.name == name,
      orElse: () => MapStyle.day,
    );
  }
}

/// Value object describing the user-editable app settings.
class AppSettings {
  final DistanceUnit speedUnit;
  final DistanceUnit distanceUnit;
  final bool darkMode;
  final bool avoidBusyJunctions;
  final bool preferWalkingPaths;
  final bool highAccuracyMode;
  final bool voiceGuidanceEnabled;
  final bool notificationsEnabled;

  const AppSettings({
    this.speedUnit = DistanceUnit.km,
    this.distanceUnit = DistanceUnit.km,
    this.darkMode = false,
    this.avoidBusyJunctions = false,
    this.preferWalkingPaths = false,
    this.highAccuracyMode = true,
    this.voiceGuidanceEnabled = true,
    this.notificationsEnabled = true,
  });

  MapStyle get mapStyle => darkMode ? MapStyle.night : MapStyle.day;

  AppSettings copyWith({
    DistanceUnit? speedUnit,
    DistanceUnit? distanceUnit,
    bool? darkMode,
    bool? avoidBusyJunctions,
    bool? preferWalkingPaths,
    bool? highAccuracyMode,
    bool? voiceGuidanceEnabled,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      speedUnit: speedUnit ?? this.speedUnit,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      darkMode: darkMode ?? this.darkMode,
      avoidBusyJunctions: avoidBusyJunctions ?? this.avoidBusyJunctions,
      preferWalkingPaths: preferWalkingPaths ?? this.preferWalkingPaths,
      highAccuracyMode: highAccuracyMode ?? this.highAccuracyMode,
      voiceGuidanceEnabled: voiceGuidanceEnabled ?? this.voiceGuidanceEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! AppSettings) return false;
    return speedUnit == other.speedUnit &&
        distanceUnit == other.distanceUnit &&
        darkMode == other.darkMode &&
        avoidBusyJunctions == other.avoidBusyJunctions &&
        preferWalkingPaths == other.preferWalkingPaths &&
        highAccuracyMode == other.highAccuracyMode &&
        voiceGuidanceEnabled == other.voiceGuidanceEnabled &&
        notificationsEnabled == other.notificationsEnabled;
  }

  @override
  int get hashCode => Object.hash(
        speedUnit,
        distanceUnit,
        darkMode,
        avoidBusyJunctions,
        preferWalkingPaths,
        highAccuracyMode,
        voiceGuidanceEnabled,
        notificationsEnabled,
      );
}