# NaVi Build Setup

NaVi has **one runtime Mapbox token source**: the Flutter define
`MAPBOX_TOKEN`.

- Dart reads it with `String.fromEnvironment('MAPBOX_TOKEN')` in
  `lib/services/mapbox_config.dart`.
- Android native maps read the same define from Gradle's `dart-defines`
  property and inject it into the `com.mapbox.token` manifest placeholder in
  `android/app/build.gradle.kts`.

There is no token in `android/gradle.properties`, no
`android/key.properties` token fallback, no `lib/config/mapbox_secrets.dart`
fallback, and no environment-variable fallback for the runtime token. Do not
paste a token into any tracked file.

---

## 1. Create your local define file

From the repository root:

```powershell
Copy-Item dart_defines.example.json dart_defines.json
notepad dart_defines.json
```

`dart_defines.json` is git-ignored. Replace the placeholder with your own Mapbox
**public** token:

```json
{
  "MAPBOX_TOKEN": "pk.your_token_here"
}
```

You can also pass the token directly on a single command:

```powershell
flutter run --dart-define=MAPBOX_TOKEN=pk.your_token_here
```

Both forms are the same Flutter define mechanism; the file form keeps the token
out of shell history.

---

## 2. Exact run/build commands

Use the local define file for every Flutter command:

```powershell
flutter run --dart-define-from-file=dart_defines.json
flutter build apk --release --dart-define-from-file=dart_defines.json
flutter build appbundle --dart-define-from-file=dart_defines.json
flutter test --dart-define-from-file=dart_defines.json
```

Plain `flutter run` and `flutter build apk` still open the app, but Mapbox API
calls have no token and will fail until the define is supplied.

---

## 3. IDE setup

### Android Studio / IntelliJ

1. Open **Run > Edit Configurations...**
2. Select the Flutter configuration for NaVi.
3. Add to **Additional arguments**:

   ```text
   --dart-define-from-file=dart_defines.json
   ```

4. Run the configuration normally. Do not build with a bare Gradle task; that
   bypasses the Flutter define and leaves the Android manifest token empty.

### VS Code

Add or merge this in `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "NaVi (local defines)",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define-from-file=dart_defines.json"]
    }
  ]
}
```

### OpenCode terminal

OpenCode uses the same shell as your terminal. Run the commands from the
project root with the define-file flag:

```powershell
flutter run --dart-define-from-file=dart_defines.json
flutter build apk --release --dart-define-from-file=dart_defines.json
```

When asking OpenCode to run or build the app, include
`--dart-define-from-file=dart_defines.json` in the command. Do not set
`MAPBOX_TOKEN` in the environment or add a native token resource; the define
file is the single source.

---

## 4. Startup check

When the define is missing, startup logs exactly:

```text
MAPBOX_TOKEN missing: set it with --dart-define
```

Debug builds also show a red, non-interactive banner at the top of the app. The
app still opens; only Mapbox-backed requests are unauthenticated.

---

## 5. Android SDK download token

`SDK_REGISTRY_TOKEN` is a separate **secret** build credential used by
`android/build.gradle.kts` to download the Mapbox Android SDK. It is not a
runtime map token and is not supplied through Flutter defines. Keep it local in
`~/.gradle/gradle.properties` or the environment:

```powershell
$env:SDK_REGISTRY_TOKEN = 'sk.YOUR_MAPBOX_SECRET_TOKEN'
```

Never commit either token.

---

## 6. iOS note

Dart-side Mapbox API calls use the same `MAPBOX_TOKEN` define on iOS. The
checked-in `ios/Runner/Info.plist` keeps `MBXAccessToken` empty; do not paste a
real token into it.

---

## Commit checklist

- [ ] `dart_defines.json` is not added to Git.
- [ ] No real `pk....` or `sk....` value appears in any tracked file.
- [ ] `android/gradle.properties` and `android/key.properties` contain no runtime token.
- [ ] Run/build commands include `--dart-define-from-file=dart_defines.json` or
      `--dart-define=MAPBOX_TOKEN=...`.
