import java.util.Properties

// Eigener Schlüssel für die App (damit Updates über die alte Version installiert
// werden können). Kommt aus android/key.properties (lokal) oder aus GitHub
// Secrets (beim automatischen Bauen). Fehlt beides, wird der Test Schlüssel benutzt.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun keyValue(name: String, env: String): String? =
    keyProps.getProperty(name) ?: System.getenv(env)?.takeIf { it.isNotBlank() }
val keyStoreFile = keyValue("storeFile", "TRY_KEYSTORE_PATH")

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "de.trymedia.try_collage"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "de.trymedia.try_collage"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyStoreFile != null) {
            create("release") {
                storeFile = file(keyStoreFile)
                storePassword = keyValue("storePassword", "TRY_KEYSTORE_PASSWORD")
                keyAlias = keyValue("keyAlias", "TRY_KEY_ALIAS")
                keyPassword = keyValue("keyPassword", "TRY_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
