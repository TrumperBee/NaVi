import '../config/mapbox_secrets.dart';

/// Resolves the Mapbox public token in one place.
///
/// Resolution order:
/// 1. `--dart-define=MAPBOX_TOKEN=pk...` at build/run time,
/// 2. the local, git-ignored `lib/config/mapbox_secrets.dart` fallback.
///
/// The fallback makes plain `flutter run` / `flutter build apk` work without
/// repeating the define on every command. It stays out of Git because that
/// file is git-ignored; `lib/config/mapbox_secrets.example.dart` is the
/// tracked template. The Android native map SDK mirrors the token into the
/// manifest from `--dart-define`, `android/key.properties`, or the
/// `MAPBOX_TOKEN` env var / Gradle property (see docs/BUILD_SETUP.md).
class MapboxConfig {
  /// Build-time define. Empty when the caller did not pass one.
  static const String _definedToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '',
  );

  /// The define wins when it is non-empty; otherwise the local token file.
  static const String accessToken =
      _definedToken == '' ? kLocalMapboxPublicToken : _definedToken;

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
