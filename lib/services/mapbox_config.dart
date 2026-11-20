class MapboxConfig {
  /// The single runtime token source.
  ///
  /// Pass it with `--dart-define=MAPBOX_TOKEN=...`, or use
  /// `--dart-define-from-file=dart_defines.json`, which is the same Flutter
  /// define mechanism. It is empty when the caller does not supply it.
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '',
  );

  /// Exact startup warning text.
  static const String missingTokenMessage =
      'MAPBOX_TOKEN missing: set it with --dart-define';

  static bool get isConfigured => accessToken.trim().isNotEmpty;

  /// Called once at startup. Uses `print` so the log line is exactly
  /// [missingTokenMessage] with no framework prefix.
  static void logMissingTokenIfNeeded() {
    if (isConfigured) return;
    // ignore: avoid_print
    print(missingTokenMessage);
  }

  static const String lightStyle = 'mapbox://styles/mapbox/navigation-day-v1';
  static const String darkStyle = 'mapbox://styles/mapbox/navigation-night-v1';

  /// Satellite imagery with street/label overlays - the second state of the
  /// homepage layers toggle.
  static const String satelliteStyle =
      'mapbox://styles/mapbox/satellite-streets-v12';

  static String styleForTheme(bool isDark) => isDark ? darkStyle : lightStyle;

  static const String defaultStyle = lightStyle;

  // API endpoints
  static const String directionsBaseUrl =
      'https://api.mapbox.com/directions/v5/mapbox';
}
