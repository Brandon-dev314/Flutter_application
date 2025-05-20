import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties().apply {
    val propFile = rootProject.file("key.properties")
    if (propFile.exists()) {
        load(FileInputStream(propFile))
    }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.gisela_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // ✅ ACTIVADO CORRECTAMENTE
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.flutter_application_1"
        minSdk = 34
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
     signingConfigs {
        // Create (or replace) the "release" signing config
        create("release") {
            keyAlias     = keystoreProperties["keyAlias"]     as String
            keyPassword  = keystoreProperties["keyPassword"]  as String
            storeFile    = file(keystoreProperties["storeFile"] as String)
            storePassword= keystoreProperties["storePassword"]as String
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false   // or true if you’re using R8/ProGuard
            isShrinkResources = false  
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.12.0"))
    implementation("com.google.firebase:firebase-analytics")

    // ✅ Esta es la forma correcta de incluir desugar_jdk_libs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
