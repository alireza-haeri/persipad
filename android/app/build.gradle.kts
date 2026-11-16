import java.util.Base64
import java.util.Properties
import java.io.FileInputStream

// remove this when flutter fix following issue:
// https://github.com/flutter/flutter/issues/139289
val dartDefines: Map<String, String> = if (gradle.startParameter.projectProperties.containsKey("dart-defines")) {
    val encoded = gradle.startParameter.projectProperties["dart-defines"]!!
    encoded.split(",").associate { entry ->
        val decoded = String(Base64.getDecoder().decode(entry), Charsets.UTF_8)
        val (key, value) = decoded.split("=")
        key to value
    }
} else {
    emptyMap()
}

fun loadKeystoreProperties(keystoreFilePath: String): Properties {
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file(keystoreFilePath)
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }
    return keystoreProperties
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // compileSdk = flutter.compileSdkVersion
    //
    // 37 is what upstream and CI build against. A machine that cannot reach
    // dl.google.com to install android-37 can build against the platform it does have:
    //   ORG_GRADLE_PROJECT_notelyCompileSdk=36 ORG_GRADLE_PROJECT_notelyCompileSdkMinor=1 bin/build_apk
    compileSdk = (project.findProperty("notelyCompileSdk") as String?)?.toIntOrNull() ?: 37
    (project.findProperty("notelyCompileSdkMinor") as String?)?.toIntOrNull()?.let { minor ->
        compileSdkMinor = minor
    }

    // The NDK is only needed when something actually compiles C/C++; nothing in this
    // app does, and the debug build does not touch it. `notelyNdkVersion=none` (or
    // bin/build_apk --no-ndk) skips sdkmanager provisioning (paired with the matching
    // entry in android/build.gradle.kts).
    val notelyNdkVersion = project.findProperty("notelyNdkVersion") as String?
    ndkVersion = if (notelyNdkVersion != "none") {
        notelyNdkVersion ?: flutter.ndkVersion
    } else {
        "28.2.13676358"
    }

    compileOptions {
        // Required by flutter_local_notifications for scheduled notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // jvmTarget lives in the Kotlin compilerOptions DSL from Kotlin 2.x on; the old
    // `kotlinOptions { jvmTarget = ... }` form is an *error* under AGP 9, not a warning.

    defaultConfig {
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter.minSdkVersion

        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // --dart-define-from-file=configs/example.json
        //
        // These two used to be `resValue(...)`. AGP 9 disables custom *resource* values
        // in the legacy DSL ("defaultConfig contains custom resource values, but the
        // feature is disabled"), and the manifest is the only reader of both, so they
        // are manifest placeholders now — the same mechanism `appLogo` below already
        // uses. The dart-define defaults are unchanged, so the storypad flavor keeps
        // overriding its own name and Maps key exactly as before.
        manifestPlaceholders["appName"] = dartDefines["APP_NAME"] ?: "StoryPad C."
        manifestPlaceholders["googleMapsApiKey"] = dartDefines["GOOGLE_MAPS_ANDROID_API_KEY"] ?: ""
    }

    signingConfigs {
        create("release") {
            val envKeystorePath = System.getenv("RELEASE_KEYSTORE_PATH")
            val envKeystorePassword = System.getenv("RELEASE_KEYSTORE_PASSWORD")
            val envKeyAlias = System.getenv("RELEASE_KEY_ALIAS")
            val envKeyPassword = System.getenv("RELEASE_KEY_PASSWORD")

            if (envKeystorePath != null) {
                storeFile = file(envKeystorePath)
                storePassword = envKeystorePassword
                keyAlias = envKeyAlias
                keyPassword = envKeyPassword
            }
        }

        getByName("debug") {
            val envKeystorePath = System.getenv("DEBUG_KEYSTORE_PATH")
            val envKeystorePassword = System.getenv("DEBUG_KEYSTORE_PASSWORD")
            val envKeyAlias = System.getenv("DEBUG_KEY_ALIAS")
            val envKeyPassword = System.getenv("DEBUG_KEY_PASSWORD")

            if (envKeystorePath != null) {
                storeFile = file(envKeystorePath)
                storePassword = envKeystorePassword
                keyAlias = envKeyAlias
                keyPassword = envKeyPassword
            }
        }
    }

    flavorDimensions.add("app")
    productFlavors {
        create("storypad") {
            dimension = "app"
            applicationId = "com.tc.writestory"
            namespace = "com.tc.writestory"
            manifestPlaceholders["appLogo"] = "storypad_logo_1_0"
            manifestPlaceholders["dropboxCallbackScheme"] = "storypad"
        }

        create("community") {
            dimension = "app"
            applicationId = "com.tc.writestory.community"
            namespace = "com.tc.writestory.community"
            manifestPlaceholders["appLogo"] = "ic_launcher"
            manifestPlaceholders["dropboxCallbackScheme"] = "storypadcommunity"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }

        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications for scheduled notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
