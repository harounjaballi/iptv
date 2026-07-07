# ============================================================
# Premium IPTV Player — règles R8/ProGuard (release Play Store)
# ============================================================

# --- Flutter ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- ExoPlayer / Media3 (utilisé par better_player_plus) ---
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**

# --- Play Core (deferred components : référencé par Flutter mais absent) ---
-dontwarn com.google.android.play.core.**

# --- flutter_secure_storage (Keystore) ---
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# --- Kotlin ---
-dontwarn kotlin.**
-keepclassmembers class kotlin.Metadata { *; }

# --- Conserver les infos utiles au débogage des crashs en prod ---
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
