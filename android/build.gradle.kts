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

if ((project.findProperty("notelyNdkVersion") as? String) == "none") {
    // Flutter's Gradle plugin (forceNdkDownload) calls sdkmanager to install
    // flutter.ndkVersion during :app configure/finalizeDsl even when nothing compiles
    // C/C++, hanging/failing where dl.google.com is blocked. Marking our matching
    // placeholder version on :app lets --no-ndk skip sdkmanager without falling back
    // to synthetic CMakeLists.txt.
    project(":app").extensions.extraProperties.set("flutter.installedNdkVersions", "28.2.13676358")
}

// super_keyboard (via storypad_editor → super_editor) pins compileSdk 34, which newer plugins' AAR metadata rejects
// ("requires … compileSdk of at least 36"). Raise every plugin module to 36 until it's updated upstream. Must come
// before evaluationDependsOn(":app"), which evaluates the plugins.
val notelyCompileSdk = (rootProject.findProperty("notelyCompileSdk") as? String)?.toIntOrNull()
val notelyCompileSdkMinor = (rootProject.findProperty("notelyCompileSdkMinor") as? String)?.toIntOrNull()
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.let { android ->
            if ((android.compileSdk ?: 0) < 36) {
                android.compileSdk = 36
            }
            // When a local SDK only has a minor platform (e.g. android-36.1 without android-36),
            // align matching plugin modules so AGP does not try to download platforms;android-36.
            if (notelyCompileSdk != null && notelyCompileSdkMinor != null && android.compileSdk == notelyCompileSdk) {
                android.compileSdkMinor = notelyCompileSdkMinor
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
