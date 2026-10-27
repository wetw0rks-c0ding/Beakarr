import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Force plugin subprojects to match the app's compileSdk so transitive
// AAR metadata checks pass. flutter_plugin_android_lifecycle >= 2.0.35
// requires minCompileSdk = 36, while file_picker 8.x pins compileSdk 34
// in its own pub-cache build.gradle and the Flutter Gradle Plugin does
// not override that for the legacy Groovy buildscript it uses.
// Registered FIRST so the afterEvaluate callback is queued on subprojects
// while they are still un-evaluated; the callback fires after each
// subproject's own android { compileSdk 34 } is evaluated and overrides it.
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android is LibraryExtension) {
                android.compileSdk = 36
            }
        }
    }
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
