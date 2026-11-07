# =============================================================================
# Brain Mantra — R8 keep rules (android/app/proguard-rules.pro)
#
# Re-enabling isMinifyEnabled/isShrinkResources (see build.gradle.kts for the
# history) requires explicit keep rules for every native plugin that uses
# reflection, JNI, or is loaded by a component the Android framework
# instantiates by class name (R8 can't see those references statically and
# will strip or rename the classes otherwise).
#
# Each block below names the plugin/library it protects and WHY.
# =============================================================================

# -----------------------------------------------------------------------------
# Flutter's deferred-components embedding code (FlutterPlayStoreSplitApplication,
# PlayStoreDeferredComponentManager) references Google Play Core's
# split-install classes defensively, even though this app doesn't use
# deferred components / dynamic feature modules at all — so those classes
# genuinely don't exist in this app's dependency tree for R8 to find.
# CONFIRMED BUILD FAILURE without this: R8 fails the build outright with
# "Missing class com.google.android.play.core.splitcompat.SplitCompatApplication"
# and similar, from :app:minifyReleaseWithR8. Safe to silence since these
# code paths are genuinely unreachable for an app with no deferred components.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# -----------------------------------------------------------------------------
# WorkManager / Room — THE CONFIRMED, ALREADY-SEEN FAILURE.
# Real crash on a physical device under AGP 9.1.0 with no keep rules:
#   "Failed to create an instance of androidx.work.impl.WorkDatabase"
# WorkManager uses Room, and Room generates DAO/database implementation
# classes at compile time that are only referenced by generated code via
# reflection — R8 has no static call site to follow, so without a keep rule
# it renames/strips them and WorkManager can't instantiate its own database
# at app startup. This is pulled in transitively, most likely by
# google_mobile_ads or supabase_flutter (neither declares WorkManager
# directly in this repo's pubspec.yaml).
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
# Room's generated implementation classes follow the pattern
# <Database>_Impl / <Dao>_Impl — keep anything ending "_Impl" defensively
# since the generated class names aren't known ahead of time here.
-keep class **_Impl { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# -----------------------------------------------------------------------------
# google_mobile_ads (AdMob) — mediation adapters and SDK internals are
# loaded via reflection by class name (mediation adapter classes are never
# referenced directly from Dart or Kotlin code, only looked up by string at
# runtime), and this is also a suspected source of the WorkManager pull-in
# above (AdMob commonly schedules background ad-session reporting via
# WorkManager).
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep public class com.google.android.gms.ads.mediation.** { *; }
-keep public class * extends com.google.android.gms.ads.mediation.Adapter { *; }
-keep public class * extends com.google.android.gms.ads.mediation.customevent.CustomEventAdapter { *; }
-dontwarn com.google.android.gms.ads.**

# -----------------------------------------------------------------------------
# google_sign_in (Credential Manager / Google Identity Services) — these
# newer Android Credential Manager APIs construct credential option/response
# classes via reflection rather than normal `new` calls, so R8's default
# shrinking (which only follows static references) can strip classes the
# Credential Manager layer still expects to find at runtime.
-keep class androidx.credentials.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn androidx.credentials.**
-dontwarn com.google.android.gms.auth.**

# -----------------------------------------------------------------------------
# firebase_messaging — background message handler bridge.
# NEVER TESTED UNDER R8: this plugin was added on feature/push-notifications
# (see Documents/PUSH_NOTIFICATIONS.md), after the one and only R8 attempt
# this project made (which failed on WorkManager, above, for an unrelated
# reason). The Dart-side background handler is a top-level function tagged
# @pragma('vm:entry-point'), invoked by a native Android bridge class that
# looks it up by name from a background isolate — if R8 renames/strips that
# bridge class, background push delivery breaks silently (no crash, no
# logcat error — the only symptom is a push that's silently never shown or
# never wakes the handler).
#
# Firebase's own Flutter plugin AARs ship consumer ProGuard rules that R8
# merges in automatically, so the baseline bridge classes should already be
# covered without hand-written rules below. These are added defensively
# anyway, because this path is untested and silent failure (not a crash) is
# the failure mode. FLAG FOR VERIFICATION: if Stage A's manual checklist
# surfaces anything push-related, check the exact bridge class name against
# Firebase's own plugin source/docs rather than trusting this comment alone.
-keep class io.flutter.plugins.firebase.messaging.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# -----------------------------------------------------------------------------
# flutter_local_notifications — AlarmManager/NotificationManager wrapper with
# its own BroadcastReceiver (notification-tap callback) and scheduled-alarm
# receiver classes. These are referenced only from AndroidManifest.xml by
# class name, not from app code, so R8 can't see the reference and will
# strip them unless kept — breaking tap-to-open and rescheduled reminders.
-keep class com.dexterous.** { *; }
-keep class * extends android.content.BroadcastReceiver { *; }
-keep class * extends android.app.job.JobService { *; }
-dontwarn com.dexterous.**

# -----------------------------------------------------------------------------
# firebase_core — foundational Firebase bootstrap via a ContentProvider-based
# auto-initializer. If this is stripped, every other Firebase plugin
# (firebase_messaging included) silently fails to initialize.
-keep class com.google.firebase.provider.** { *; }
-keep class com.google.firebase.components.** { *; }
-dontwarn com.google.firebase.components.**

# -----------------------------------------------------------------------------
# supabase_flutter — HTTP/realtime client; mostly pure-Dart, but its Android
# host side touches OkHttp/Gson-style reflection in some transitive deps.
# Kept defensively since this plugin was named alongside google_mobile_ads
# as a suspected source of the original WorkManager pull-in.
-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod
-keep class com.google.gson.** { *; }
-dontwarn okhttp3.**
-dontwarn org.conscrypt.**

# -----------------------------------------------------------------------------
# General Flutter-plugin-safe baseline — standard rules needed by virtually
# every Flutter release build with native plugins attached, independent of
# which plugins are in use.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Keep Parcelable CREATOR fields and Serializable classes — stripped/renamed
# versions break Android's cross-process (de)serialization (notification
# payloads, intents) at runtime with no compile-time warning.
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keepnames class * implements java.io.Serializable

# Keep enum values()/valueOf() — R8 can otherwise break these for enums
# referenced only via reflection or a framework callback.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
