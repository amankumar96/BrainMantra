import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: reads android/key.properties (NEVER committed - see
// key.properties.example and Documents/FOUNDER_LAUNCH_GUIDE.md). If the
// file doesn't exist yet, release builds fall back to the debug key so
// `flutter run --release` still works on a dev machine - but such a build
// can NOT be uploaded to Google Play.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.brainmantra.app"
    compileSdk = flutter.compileSdkVersion
    // Pinned to the NDK version actually installed on this machine via
    // Android Studio's SDK Manager - flutter.ndkVersion's own default
    // (28.2.13676358) isn't installed here, and letting Gradle
    // auto-download it crashes the deprecated sdkmanager.bat outright.
    ndkVersion = "30.0.16138531"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.brainmantra.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Code shrinking (R8) is left OFF deliberately. AGP 9's default
            // release behaviour renames/strips classes, which broke
            // WorkManager's Room database at startup (a transitive
            // dependency, likely pulled in by google_mobile_ads or
            // supabase_flutter) with no keep rules in place to protect it
            // — confirmed via a real crash on a physical device (logcat:
            // "Failed to create an instance of androidx.work.impl.
            // WorkDatabase"). A smaller, obfuscated build is a worthwhile
            // later optimization, but needs its own dedicated round of
            // R8 keep-rule testing rather than shipping it untested.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
