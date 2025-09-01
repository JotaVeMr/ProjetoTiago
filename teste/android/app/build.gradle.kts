plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "tiago.teste"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true 
    }
   

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

   defaultConfig {
    applicationId = "tiago.teste"
    minSdkVersion(23)
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
}

    buildTypes {
        release {
            // TODO: Adicione sua própria configuração de assinatura para a build de release.
            // Assinando com as chaves de depuração por enquanto, para que `flutter run --release` funcione.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
