# TensorFlow Lite ProGuard rules
-keep class org.tensorflow.lite.** { *; }
-keep class com.google.android.gms.tflite.** { *; }
-dontwarn org.tensorflow.lite.**

# Flutter and Native plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }

# Google Play Core and deferred components suppression
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
