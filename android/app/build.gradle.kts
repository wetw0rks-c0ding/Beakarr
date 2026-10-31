import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()

if (hasKeystoreProperties) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

val requiredReleaseSigningKeys = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)

val missingReleaseSigningKeys = if (hasKeystoreProperties) {
    requiredReleaseSigningKeys.filter {
        keystoreProperties.getProperty(it).isNullOrBlank()
    }
} else {
    requiredReleaseSigningKeys
}

val hasCompleteReleaseSigning =
    hasKeystoreProperties && missingReleaseSigningKeys.isEmpty()

val wantsRelease = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (wantsRelease) {
    if (!hasKeystoreProperties) {
        throw GradleException(
            "Missing release signing config: android/key.properties. Copy android/key.properties.example and fill in real values.",
        )
    }

    if (!hasCompleteReleaseSigning) {
        throw GradleException(
            "android/key.properties is missing required values: ${missingReleaseSigningKeys.joinToString(", ")}",
        )
    }
}

android {
    namespace = "labs.wetw0rks.beakarr"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "labs.wetw0rks.beakarr"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage 10.x requires Android 23+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasCompleteReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasCompleteReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
