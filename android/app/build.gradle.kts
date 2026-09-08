import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---- Upload signing -------------------------------------------------------
// Credentials live in android/key.properties, which is git-ignored: the
// keystore and its passwords must never be committed. See key.properties.example
// and docs/DEPLOY.md section 4.
//
// If that file is absent (a fresh clone, CI, someone else's machine) the release
// build falls back to the DEBUG key so `flutter build apk --release` still
// produces an installable test APK — with a loud warning, because Play rejects
// debug-signed uploads and that must not be discovered at upload time.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasUploadKey = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (hasUploadKey) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.perfeos.step_quest"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs core-library desugaring for the
        // java.time APIs it uses on older Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // NOTE: permanent once published, and it also names the IAP products.
        // See docs/PLAY_LISTING.md section 6 before the first upload.
        applicationId = "com.perfeos.step_quest"
        minSdk = 26 // Health Connect requires Android 8.0+ (doc §3.4)
        targetSdk = flutter.targetSdkVersion
        // Both come from `version:` in pubspec.yaml (0.1.0+1 -> name 0.1.0,
        // code 1). Play needs a HIGHER versionCode on every upload, so bump the
        // +N. Keep lib/core/app_info.dart in step — a test enforces it, so
        // forgetting fails the suite rather than shipping a mislabelled build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                // Fail at CONFIGURE time with a readable message. The native
                // errors for a missing property or a mistyped path are awful,
                // and this is the one build you cannot afford to fumble.
                val required =
                    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
                val missing = required.filter {
                    keystoreProperties.getProperty(it).isNullOrBlank()
                }
                if (missing.isNotEmpty()) {
                    throw GradleException(
                        "android/key.properties is missing: " +
                            missing.joinToString(", ") +
                            ". See android/key.properties.example."
                    )
                }

                // A relative storeFile resolves against android/ (where
                // key.properties itself lives), which is the least surprising
                // reading. An absolute path is safest.
                val configured = keystoreProperties.getProperty("storeFile")
                val store = File(configured).let {
                    if (it.isAbsolute) it else rootProject.file(configured)
                }
                if (!store.exists()) {
                    throw GradleException(
                        "Upload keystore not found at " + store.absolutePath +
                            " (storeFile in android/key.properties)."
                    )
                }

                storeFile = store
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// `flutter build` swallows most Gradle output, so a printed warning is not
// enough protection on its own. Hard-fail the APP BUNDLE — the artifact you
// actually upload — when there is no upload key. An APK still builds
// debug-signed for local testing; a .aab you would only discover was
// unuploadable at the Play Console does not.
gradle.taskGraph.whenReady {
    if (!hasUploadKey &&
        allTasks.any { it.name.startsWith("bundle") && it.name.contains("Release") }
    ) {
        throw GradleException(
            "Cannot build a release App Bundle without an upload key: " +
                "android/key.properties is missing, so this would be signed " +
                "with the DEBUG key and Play would reject it. " +
                "See android/key.properties.example and docs/DEPLOY.md section 4. " +
                "(`flutter build apk --release` still works for test installs.)"
        )
    }
}

if (!hasUploadKey) {
    logger.warn("============================================================")
    logger.warn("WARNING: no android/key.properties found.")
    logger.warn("Release builds are being signed with the DEBUG key.")
    logger.warn("Installable for testing; NOT uploadable — Play rejects")
    logger.warn("debug-signed artifacts. See docs/DEPLOY.md section 4.")
    logger.warn("============================================================")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
