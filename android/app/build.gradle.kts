import java.util.Base64
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Add this line
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.android.application"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.android.application"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Mapbox public token — one source only: Flutter's --dart-define.
        // Flutter forwards defines to Gradle as base64 KEY=VALUE entries in
        // the `dart-defines` project property. Decode the same value used by
        // lib/services/mapbox_config.dart and inject it into the manifest.
        val dartDefines: List<String> =
            (project.findProperty("dart-defines") as String? ?: "")
                .split(',')
                .filter { it.isNotEmpty() }
        val defineMap: Map<String, String> = dartDefines.mapNotNull { enc ->
            runCatching {
                val pair =
                    String(Base64.getDecoder().decode(enc), Charsets.UTF_8)
                val idx = pair.indexOf('=')
                if (idx <= 0) null else pair.substring(0, idx) to pair.substring(idx + 1)
            }.getOrNull()
        }.toMap()

        manifestPlaceholders["MAPBOX_TOKEN"] = defineMap["MAPBOX_TOKEN"].orEmpty()
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
