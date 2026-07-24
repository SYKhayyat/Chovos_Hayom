import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is loaded from android/key.properties, which is git-ignored (a
// keystore password in version control is a keystore you have to replace). When
// the file is absent — a fresh clone, or CI without secrets — release builds
// fall back to the debug key so `flutter run --release` still works, but such a
// build is debug-signed and NOT distributable. The README documents exactly this.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.sykhayyat.chovos_hayom"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.sykhayyat.chovos_hayom"
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Only create the release config when the keystore is actually present;
        // referencing an absent storeFile would fail the build even for a debug
        // developer who just wants to run the app.
        if (hasReleaseKeystore) {
            create("release") {
                // storeFile is resolved relative to android/app/, matching the
                // note in key.properties.example.
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // The real keystore when it exists; the debug key otherwise, so an
            // unsigned-for-release checkout still builds (and is clearly not
            // distributable — see the README's Releasing section).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 code shrinking + obfuscation. proguard-rules.pro keeps the
            // plugins that reach native code reflectively (drift/sqlite3, platform
            // channels) — without minify on, that file, though committed, does
            // nothing, which is the exact "written but never wired" defect this
            // file had. Resource shrinking is deliberately left off: it is the
            // more fragile half of R8 and buys little for a Flutter app (whose
            // assets are Flutter's, not Android resources), so its risk isn't
            // worth taking without a device to verify against.
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
