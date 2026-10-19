// Luduvo Android port — Qt6 + SDL3 + Vulkan (NDK) — Native Engine Build
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") version "1.9.20"
}

android {
    namespace = "com.luduvo.client"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.luduvo.client"
        minSdk = 28   // Vulkan 1.1 baseline
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        // 32/64-bit universal APK (ABI split handled by bundle)
        ndk {
            abiFilters = listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }

        externalNativeBuild {
            cmake {
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DLDV_PLATFORM=android",
                    "-DCMAKE_BUILD_TYPE=Release",
                    "-DLDV_ENABLE_VULKAN=ON",
                    "-DLDV_ENABLE_MOLTENVK=OFF"
                )
            }
        }

        // Native libraries packaging
        packagingOptions {
            jniLibs {
                useLegacyPackaging = true
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            isDebuggable = true
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("keystore/release.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "buildoverse"
            keyAlias = "buildoverse"
            keyPassword = System.getenv("KEY_PASSWORD") ?: "buildoverse"
        }
        create("debug") {
            storeFile = file("keystore/debug.jks")
            storePassword = "buildoverse"
            keyAlias = "buildoverse"
            keyPassword = "buildoverse"
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildFeatures {
        viewBinding = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.20")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.activity:activity-ktx:1.8.2")
}