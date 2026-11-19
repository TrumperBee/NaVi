# NaVi Build Setup

How to supply the Mapbox tokens when building NaVi locally. Nothing here is
committed to the repo — all values below are **local-only**.

Why this exists: `MapboxConfig.accessToken` in
`lib/services/mapbox_config.dart` reads
`String.fromEnvironment('MAPBOX_TOKEN', defaultValue: '')`. Without a real
token at build time every Mapbox geocode request returns **401** and landmark
searches silently come back empty (see
[`docs/navigation_rendering_audit.md`](navigation_rendering_audit.md),
Symptom 3).

NaVi uses **two** Mapbox credentials:

| Token | Where it comes from | What it powers |
|-------|--------------------|----------------|
| `MAPBOX_TOKEN` (`pk....`, public/publishable) | You supply it locally | Geocoding (Dart), Android/iOS native map rendering |
| `SDK_REGISTRY_TOKEN` (`sk....`, secret) | You supply it locally | Downloading the Mapbox **Android** SDK from Mapbox's Maven registry (`android/build.gradle.kts:12-23`) |

Only the first one is required for the geocoder fix; the second is required for
Android builds to resolve the mapbox SDK at all.

---

## 1. The canonical way: pass the token to every build/run command

The Flutter process reads `--dart-define` (Dart side) and forwards it to the
Android build (native side), so **one flag covers both**:

```bash
# Run on an Android emulator/device (debug)
flutter run --dart-define=MAPBOX_TOKEN=pk.live.YOUR_MAPBOX_PUBLIC_TOKEN

# Release APK / Play bundle
flutter build apk --dart-define=MAPBOX_TOKEN=pk.live.YOUR_MAPBOX_PUBLIC_TOKEN
flutter build appbundle --dart-define=MAPBOX_TOKEN=pk.live.YOUR_MAPBOX_PUBLIC_TOKEN
```

Without the flag, `MapboxConfig.accessToken` is `''`, geocoding 401s, and (for
Android native map rendering) the manifest placeholder
`com.mapbox.token` is empty.

## 2. Don't paste the token on every command line

To keep the token out of shell history and out of every command, store it in a
gitignored file and use `--dart-define-from-file`:

1. Create `.mapbox_token.json` in the project root (this exact filename is
   gitignored):
   ```json
   { "MAPBOX_TOKEN": "pk.live.YOUR_MAPBOX_PUBLIC_TOKEN" }
   ```
2. Build with it:
   ```bash
   flutter run --dart-define-from-file=.mapbox_token.json
   flutter build apk --dart-define-from-file=.mapbox_token.json
   flutter build appbundle --dart-define-from-file=.mapbox_token.json
   ```

(Dart always receives defines from the file; on current Flutter the native
Android build also sees them through the same `dart-defines` channel.)

## 2b. Local Dart fallback for plain `flutter run` / `flutter build apk`

To avoid repeating the flag on every command, this repo also supports a
**git-ignored Dart file**:

1. Copy the tracked template once:
   ```powershell
   Copy-Item lib\config\mapbox_secrets.example.dart lib\config\mapbox_secrets.dart
   ```
2. Replace the placeholder in `lib/config/mapbox_secrets.dart` with your
   public token (`pk....`). That path is in `.gitignore`, so it never reaches
   Git history or GitHub push protection.
3. Run/build normally:
   ```powershell
   flutter run
   flutter build apk
   ```

Resolution order in `lib/services/mapbox_config.dart`:
`String.fromEnvironment('MAPBOX_TOKEN')` → `kLocalMapboxPublicToken` from the
local file. An explicitly passed `--dart-define` always wins.

This only covers the Dart side (geocoding and `MapboxOptions.setAccessToken`).
The Android native map still needs its Gradle-side token (Section 4 below, or
`--dart-define`, or `android/key.properties`).

## 3. Android native fallback when building from Android Studio / gradle directly

If you build from Android Studio or invoke `gradlew` directly (no
`flutter run`), the `--dart-define` channel is not present. Create
`android/key.properties` (gitignored; see `android/key.properties.example`):

```properties
MAPBOX_TOKEN=pk.live.YOUR_MAPBOX_PUBLIC_TOKEN
```

The app's `android/app/build.gradle.kts` resolves the manifest token in this
order: `--dart-define` → `android/key.properties` →
`MAPBOX_TOKEN` env var / gradle property. Note the Android Studio path only
feeds the **native map SDK**; the Dart geocoder still needs step 1 or 2 on a
`flutter run`/`flutter build` invocation.

## 4. Android Maven registry (SDK download) token — `SDK_REGISTRY_TOKEN`

The Mapbox **Android** SDK is resolved from
`https://api.mapbox.com/downloads/v2/releases/maven`
(`android/build.gradle.kts:11-21`). This is a *secret* download token from
your Mapbox account ("Access Tokens → secret token") and is read as a Gradle
project property. Supply it one of these local-only ways (never commit it):

**Option A — persistently in `~/.gradle/gradle.properties`:**

```properties
SDK_REGISTRY_TOKEN=sk.YOUR_MAPBOX_SECRET_TOKEN
```

**Option B — environment variable** (your local build also falls back to it,
see `android/build.gradle.kts:19-21`):

```bash
# Linux/macOS
export SDK_REGISTRY_TOKEN=sk.YOUR_MAPBOX_SECRET_TOKEN
flutter build apk --dart-define=MAPBOX_TOKEN=pk.live.YOUR_MAPBOX_PUBLIC_TOKEN

# PowerShell
$env:SDK_REGISTRY_TOKEN = 'sk.YOUR_MAPBOX_SECRET_TOKEN'
flutter build apk --dart-define=MAPBOX_TOKEN=pk.live.YOUR_MAPBOX_PUBLIC_TOKEN
```

Gradle also maps `ORG_GRADLE_PROJECT_SDK_REGISTRY_TOKEN` onto the project
property if you prefer that convention. Without this token the Android build
cannot download the Mapbox SDK (401 from the Maven registry).

## 5. Verify the token actually reached the build

**Dart side (geocoder):** run with the token (Step 1 or 2), then search a
Nairobi landmark in the app. A token that landed returns Mapbox results (the
search source reads `Resolved via Mapbox`); a missing token reads
`Geocoding limited — showing local stage matches` (every request 401s).

**Android native side (manifest placeholder):** after
`flutter build apk --debug --dart-define=MAPBOX_TOKEN=pk.live.YOUR_MAPBOX_PUBLIC_TOKEN`,
check the merged manifest:

```bash
# PowerShell, from the repo root
Select-String -Path 'build\app\intermediates\**\*.xml' -Pattern 'com.mapbox.token' -Context 0,1
```

The value must be your `pk...` token — not empty, not the literal
`${MAPBOX_TOKEN}` placeholder.

## 6. iOS / macOS notes

`ios/Runner/Info.plist` declares `MBXAccessToken` as an empty string (never
committed with a value). For native iOS rendering, inject it at build time via
an Xcode build setting (e.g. `$(MAPBOX_TOKEN)` from a local, untracked
`.xcconfig`). The **Dart geocoder** on iOS still gets the token from
`--dart-define`/`--dart-define-from-file` exactly as on Android — Steps 1-2
cover the geocoder on every platform.

## Checklist before a commit that touches build files

- [ ] No `MAPBOX_TOKEN=/SDK_REGISTRY_TOKEN=` values, empty or real, in any
      committed file.
- [ ] `android/key.properties`, `.mapbox_token.json`,
      `android/local.properties` are never added to git.
- [ ] Anyone cloning the repo can still `flutter analyze`/build minus the map
      token — it only affects requests against Mapbox services at runtime.