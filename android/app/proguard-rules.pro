# Google ML Kit Text Recognition
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }

# Keep Latin text recognizer (the only one we use)
-keep class com.google.mlkit.vision.text.latin.** { *; }

# Ignore missing language-specific recognizers we don't use
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep text recognizer implementation
-keepclassmembers class com.google.mlkit.vision.text.TextRecognizer {
    public *;
}

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Prevent obfuscation of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
