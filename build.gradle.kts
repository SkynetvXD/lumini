import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") version "4.4.1"
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
android {
    namespace = "com.cogluna.lumimi"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11  // Era VERSION_11
        targetCompatibility = JavaVersion.VERSION_11  // Era VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.cogluna.lumimi"
        minSdk = 21  // Mínimo para Firebase
        targetSdk = 34  // Definir versão específica
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
           release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BoM - garante versões compatíveis
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))

    // Firebase Authentication
    implementation("com.google.firebase:firebase-auth")

    // Google Sign In
    implementation("com.google.android.gms:play-services-auth:20.7.0")
}