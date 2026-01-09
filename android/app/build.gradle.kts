// Bu konfigürasyon, artık Flutter'ın talep ettiği SDK 36'ya ve bu SDK'yı destekleyen
// daha güncel Gradle/Kotlin sürümlerine odaklanmaktadır.

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // AGP 8.1.0, SDK 36 ve modern Kotlin ile uyumludur.
        classpath("com.android.tools.build:gradle:8.1.0") 
        // Kotlin 1.9.20 AGP 8.1.0 ile kararlıdır.
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.20")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.binicilik_okulu_app"
    // Flutter'ın istediği SDK 36'ya ayarlandı.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Java 17 Flutter ile uyumludur.
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.binicilik_okulu_app"
        minSdk = flutter.minSdkVersion
        // Flutter'ın istediği SDK 36'ya ayarlandı.
        targetSdk = 36 
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}