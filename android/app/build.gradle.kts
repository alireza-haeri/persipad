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

    // Transitive :jni (pulled by path_provider_android) compiles libdartjni.so via
    // CMake + NDK, so Android builds normally need an NDK on disk. `notelyNdkVersion`
    // lets local machines use whichever NDK version is installed on disk (paired with
    // android/build.gradle.kts to align :jni), or `none` if :jni is ever removed.
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
        // This used to be `resValue(...)`. AGP 9 disables custom *resource* values
        // in the legacy DSL ("defaultConfig contains custom resource values, but the
        // feature is disabled"), and the manifest is the only reader, so it is a
        // manifest placeholder now — the same mechanism `appLogo` below already uses.
        manifestPlaceholders["appName"] = dartDefines["APP_NAME"] ?: "PersiPad"

        // `--target-platform=android-arm64` only selects Flutter's engine and Dart
        // snapshot. Plugin .so files are packaged for **every** ABI regardless, which
        // is why a "phone-only" release still carried ObjectBox's JNI library for
        // x86_64 and armeabi-v7a (~4.3 MB of libraries that phone can never load).
        // bin/build_apk passes the chosen ABI here; `--abi all` leaves it unset.
        (project.findProperty("notelyAbi") as String?)?.trim()?.takeIf { it.isNotEmpty() }?.let { abi ->
            ndk { abiFilters += abi.split(",").map { it.trim() }.filter { it.isNotEmpty() } }
        }
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
        }

        create("community") {
            dimension = "app"
            applicationId = "com.tc.writestory.community"
            namespace = "com.tc.writestory.community"
            manifestPlaceholders["appLogo"] = "ic_launcher"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }

        release {
            signingConfig = signingConfigs.getByName("release")

            // R8 + resource shrinking. Dart is tree-shaken by the AOT compiler itself;
            // this removes what it cannot see — unused Java/Kotlin code and resources
            // from ~40 plugins (Firebase, ObjectBox, image/video pickers, …).
            // They must stay in lockstep: `isShrinkResources` without minification is an
            // AGP error, not a warning.
            //
            // Escape hatch, if a plugin ever needs a keep rule and the release build dies
            // in `minifyReleaseWithR8`:
            //   bin/build_apk --release --sign-debug --abi arm64 -PnotelyMinify=false
            //   (or ORG_GRADLE_PROJECT_notelyMinify=false)
            val minify = (project.findProperty("notelyMinify") as String?)?.toBoolean() ?: true
            isMinifyEnabled = minify
            isShrinkResources = minify
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
