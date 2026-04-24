# FlyConnect ProGuard rules
# https://developer.android.com/build/shrink-code

# ===== Firebase =====
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# ===== Firebase Auth (Google + Apple sign-in) =====
-keep class com.google.firebase.auth.** { *; }

# ===== Firebase Messaging (FCM) =====
-keep class com.google.firebase.messaging.** { *; }

# ===== Google Sign-In =====
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ===== Sign in with Apple =====
-keep class com.aboutyou.dart_packages.sign_in_with_apple.** { *; }

# ===== image_picker =====
-keep class androidx.lifecycle.** { *; }

# ===== flutter_map / latlong2 (no reflection-heavy code, safe) =====

# ===== Gson / JSON serialization (in case any dependency uses it) =====
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# ===== Keep model classes (Firestore de/serialization) =====
-keep class * implements java.io.Serializable { *; }

# ===== Flutter embedding =====
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# ===== Kotlin reflection stripping =====
-keep class kotlin.Metadata { *; }

# ===== shared_preferences =====
-keep class androidx.preference.** { *; }

# ===== url_launcher =====
-keep class androidx.browser.** { *; }

# ===== image_picker =====
-keep class io.flutter.plugins.imagepicker.** { *; }

# ===== General Android / Jetpack =====
-keep class androidx.core.** { *; }
-keep class androidx.activity.** { *; }
-keep class androidx.fragment.** { *; }
-dontwarn androidx.**
