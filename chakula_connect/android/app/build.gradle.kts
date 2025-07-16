plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // Required for Firebase
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.chakulaconnect.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.chakulaconnect.app" // Must match Firebase project package
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // ✅ Helpful for Firebase with many dependencies
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // Replace with real signing config for release
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

flutter {
    source = "../.."
}
