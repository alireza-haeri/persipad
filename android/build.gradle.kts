allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

val notelyNdkVersion = project.findProperty("notelyNdkVersion") as? String
if (notelyNdkVersion == "none") {
    // Flutter's Gradle plugin (forceNdkDownload) calls sdkmanager to install
    // flutter.ndkVersion during :app configure/finalizeDsl even when nothing compiles
    // C/C++, hanging/failing where dl.google.com is blocked. Marking our matching
    // placeholder version on :app lets --no-ndk skip sdkmanager without falling back
    // to synthetic CMakeLists.txt (only usable when no plugin invokes externalNativeBuild).
    project(":app").extensions.extraProperties.set("flutter.installedNdkVersions", "28.2.13676358")
} else if (!notelyNdkVersion.isNullOrBlank()) {
    // When a local machine only has a different installed NDK version (e.g. from a
    // mirror) than Flutter's pinned 28.2.13676358, tell forceNdkDownload that the
    // installed version is ready and align plugin modules (such as :jni) below.
    project(":app").extensions.extraProperties.set("flutter.installedNdkVersions", notelyNdkVersion)
}

// super_keyboard (via storypad_editor → super_editor) pins compileSdk 34, which newer plugins' AAR metadata rejects
// ("requires … compileSdk of at least 36"). Raise every plugin module to 36 until it's updated upstream. Must come
// before evaluationDependsOn(":app"), which evaluates the plugins.
val notelyCompileSdk = (rootProject.findProperty("notelyCompileSdk") as? String)?.toIntOrNull()
val notelyCompileSdkMinor = (rootProject.findProperty("notelyCompileSdkMinor") as? String)?.toIntOrNull()
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.let { android ->
            val floor = if (notelyCompileSdk != null && notelyCompileSdk < 36) notelyCompileSdk else 36
            if ((android.compileSdk ?: 0) < floor) {
                android.compileSdk = floor
            }
            if (notelyCompileSdk != null && (android.compileSdk ?: 0) > notelyCompileSdk) {
                android.compileSdk = notelyCompileSdk
            }
            // When a local SDK only has a minor platform (e.g. android-36.1 without android-36),
            // align matching plugin modules so AGP does not try to download platforms;android-36.
            if (notelyCompileSdk != null && notelyCompileSdkMinor != null && android.compileSdk == notelyCompileSdk) {
                android.compileSdkMinor = notelyCompileSdkMinor
            }
            if (!notelyNdkVersion.isNullOrBlank() && notelyNdkVersion != "none") {
                android.ndkVersion = notelyNdkVersion
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
