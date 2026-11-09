import java.io.File

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.oadrianrabelo.livrocaixa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Exigido pelos lembretes (flutter_local_notifications).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "io.github.oadrianrabelo.livrocaixa"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // O CI passa --build-name/--build-number calculados a partir da versão.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // A assinatura de release vem de variáveis de ambiente (o CI as preenche a
    // partir dos secrets). Sem elas, usa a chave de debug para `flutter run --release`.
    // IMPORTANTE: o Android só aceita a atualização se for assinada com a MESMA chave.
    val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
    signingConfigs {
        if (keystorePath != null) {
            create("release") {
                storeFile = File(keystorePath)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: "livrocaixa"
                keyPassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
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

dependencies {
    // FileProvider: entrega o APK baixado ao instalador do Android.
    implementation("androidx.core:core:1.13.1")
    // Tema AppCompat para a digital (local_auth) não travar em Androids antigos.
    implementation("androidx.appcompat:appcompat:1.7.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
