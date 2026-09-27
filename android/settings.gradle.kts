pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    // Declared here, applied in app/build.gradle.kts. This is the plugin that
    // reads android/app/google-services.json at build time and turns it into
    // Android string resources - among them default_web_client_id, which is
    // where google_sign_in finds the web OAuth client id on Android.
    id("com.google.gms.google-services") version "4.5.0" apply false
}

include(":app")
