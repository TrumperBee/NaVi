/// Template for the local, git-ignored Mapbox token override.
///
/// Copy this file to `lib/config/mapbox_secrets.dart` and replace the
/// placeholder with your own public token (a `pk.` token from your Mapbox
/// account):
///
/// ```powershell
/// Copy-Item lib\config\mapbox_secrets.example.dart lib\config\mapbox_secrets.dart
/// ```
///
/// The real file is git-ignored, so the token never reaches Git history or
/// GitHub's push protection. `MapboxConfig` reads
/// `String.fromEnvironment('MAPBOX_TOKEN')` first and only falls back to this
/// constant when no `--dart-define` was supplied.
const String kLocalMapboxPublicToken = 'pk.your_mapbox_public_token_here';
