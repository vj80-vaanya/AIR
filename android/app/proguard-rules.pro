# ── Our own Kotlin services (referenced by name in AndroidManifest) ──────────
-keep class com.aisecurity.app.** { *; }
-dontwarn com.aisecurity.app.**

# ── Flutter embedding ─────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**

# ── ONNX Runtime ──────────────────────────────────────────────────────────────
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# ── Google ML Kit ─────────────────────────────────────────────────────────────
# Only Latin script is used. The plugin references optional CJK/Devanagari
# modules at runtime but they are not bundled — suppress R8 missing-class errors.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ── AndroidX + Google Play Core ───────────────────────────────────────────────
-keep class androidx.** { *; }
-dontwarn androidx.**
-dontwarn com.google.android.play.core.**

# ── Kotlin stdlib ─────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings { <fields>; }

# ── Android system components ────────────────────────────────────────────────
-keep public class * extends android.service.notification.NotificationListenerService
-keep public class * extends android.accessibilityservice.AccessibilityService
-keep public class * extends android.content.BroadcastReceiver

# ── Preserve stack traces for crash reporting ─────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ── Strip verbose logging from release builds ─────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
    public static int i(...);
}
