# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Dio / OkHttp
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.** { *; }

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# flutter_image_compress
-keep class com.fluttercandies.compressimage.** { *; }
-dontwarn com.fluttercandies.**
