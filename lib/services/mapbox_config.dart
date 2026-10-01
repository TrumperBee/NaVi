class MapboxConfig {
  // The Mapbox token is injected at build time and is never committed to the
  // repo, so it stays out of push-protection / secret scanners:
  //
  //   flutter run --dart-define=MAPBOX_TOKEN=pk.<your-token>
  //
  // (Android native also reads MAPBOX_TOKEN from `~/.gradle/gradle.properties`,
  // mirrored into the manifest at build time.) Builds without the define get
  // an empty token and fail loudly at runtime instead of silently degrading.
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '',
  );

  static const String lightStyle = 'mapbox://styles/mapbox/navigation-day-v1';
  static const String darkStyle = 'mapbox://styles/mapbox/navigation-night-v1';

  static String styleForTheme(bool isDark) => isDark ? darkStyle : lightStyle;

  static const String defaultStyle = lightStyle;

  // API endpoints
  static const String directionsBaseUrl =
      'https://api.mapbox.com/directions/v5/mapbox';
}
