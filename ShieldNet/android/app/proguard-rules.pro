# ==============================================================================
# ShieldNet - Regles ProGuard / R8 pour Optimisation & Minification Release
# ==============================================================================

# 1. Preservation du moteur Flutter et des plugins natifs
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 2. Workmanager (Taches de fond et synchronisation native)
-keep class androidx.work.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }

# 3. SQLite Local (sqflite)
-keep class com.tekartik.sqflite.** { *; }

# 4. Sentry (Supervision & Crash reporting)
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# 5. AndroidX Security Crypto & MasterKey
-keep class androidx.security.crypto.** { *; }

# 6. CallScreeningService et PhoneState (Filtrage natif Android Telecom)
-keep class android.telecom.CallScreeningService { *; }
-keep class com.shieldnet.shieldnet.** { *; }

# 7. Core Library Desugaring
-dontwarn java.time.**
-dontwarn java.util.concurrent.**

# 8. Preservation des signatures et annotations
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn javax.annotation.**
-dontwarn com.google.android.play.core.**
