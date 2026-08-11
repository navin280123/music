# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep audio related classes
-keep class com.google.android.exoplayer2.** { *; }

# Keep permission handler
-keep class com.baseflow.permissionhandler.** { *; }

# Suppress warnings
-dontwarn io.flutter.embedding.**
