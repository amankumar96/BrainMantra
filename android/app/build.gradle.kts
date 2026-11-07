import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
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
        // Required by flutter_local_notifications' Android implementation
        // (java.time APIs on API levels below 26) — without this the build
        // fails outright at :app:checkDebugAarMetadata.
        isCoreLibraryDesugaringEnabled = true
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
            // Code shrinking/obfuscation/optimization (R8) — RE-ENABLED.
            // History: this was off because AGP 9.1.0's default release
            // behaviour broke WorkManager's Room database with no keep rules
            // in place (confirmed crash: "Failed to create an instance of
            // androidx.work.impl.WorkDatabase"). proguard-rules.pro now
            // carries explicit keep rules for WorkManager/Room plus every
            // other native-plugin surface identified as a risk
            // (google_mobile_ads, google_sign_in, firebase_messaging,
            // flutter_local_notifications) — see that file for details.
            // Required ahead of Google Play's Feb 2027 DEX-optimization
            // policy (apps over 10MB of DEX code need >=25% shrinking/
            // obfuscation/optimization). Re-enabled in stages — Stage A
            // here is code shrinking only (isShrinkResources stays off
            // until Stage A passes a full manual verification pass on a
            // real device; see the commit history on feature/r8-shrinking
            // for when it's flipped on).
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

dependencies {
    // Pairs with isCoreLibraryDesugaringEnabled above — the actual
    // desugared-API implementation flutter_local_notifications needs.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
