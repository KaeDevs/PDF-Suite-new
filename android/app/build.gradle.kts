import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}


android {
    namespace = "com.example.pdfscanner"
    compileSdk = 36
    ndkVersion = "27.0.12077973" 

    compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlinOptions {
    jvmTarget = JavaVersion.VERSION_17.toString()
}


    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "infoway.pdf.suite"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    val storeFilePath = keystoreProperties["storeFile"]?.toString()
    ?: throw GradleException("Missing 'storeFile' in key.properties")
val storePassword = keystoreProperties["storePassword"]?.toString()
    ?: throw GradleException("Missing 'storePassword' in key.properties")
val keyAlias = keystoreProperties["keyAlias"]?.toString()
    ?: throw GradleException("Missing 'keyAlias' in key.properties")
val keyPassword = keystoreProperties["keyPassword"]?.toString()
    ?: throw GradleException("Missing 'keyPassword' in key.properties")

signingConfigs {
    create("release") {
        storeFile = file(storeFilePath)
        this.storePassword = storePassword
        this.keyAlias = keyAlias
        this.keyPassword = keyPassword
    }
}


    buildTypes {
        getByName("release") {
        isMinifyEnabled = true
        isShrinkResources = true
        signingConfig = signingConfigs.getByName("release")
        
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
    }
}

flutter {
    source = "../.."
}

