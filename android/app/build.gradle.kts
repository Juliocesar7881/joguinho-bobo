import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesPath =
    providers.environmentVariable("LEXINEXO_KEY_PROPERTIES").orNull?.trim()?.takeIf { it.isNotEmpty() }
val releaseSigningProperties = Properties()

if (releaseSigningPropertiesPath != null) {
    val propertiesFile = file(releaseSigningPropertiesPath)
    if (!propertiesFile.isFile) {
        throw GradleException(
            "LEXINEXO_KEY_PROPERTIES does not point to a readable file: ${propertiesFile.absolutePath}",
        )
    }
    propertiesFile.inputStream().use(releaseSigningProperties::load)
}

gradle.taskGraph.whenReady {
    val releaseTasksInGraph =
        allTasks.filter { task ->
            task.project == project && task.name.contains("release", ignoreCase = true)
        }
    if (releaseTasksInGraph.isNotEmpty() && releaseSigningPropertiesPath == null) {
        val requestedReleaseTasks = releaseTasksInGraph.joinToString(", ") { it.path }
        throw GradleException(
            "Release signing is not configured for task graph: $requestedReleaseTasks. " +
                "Set LEXINEXO_KEY_PROPERTIES to the external keystore properties file.",
        )
    }
}

fun requiredReleaseSigningProperty(name: String): String {
    val value = releaseSigningProperties.getProperty(name)?.trim()
    if (value.isNullOrEmpty()) {
        throw GradleException("Missing required release signing property: $name")
    }
    return value
}

android {
    namespace = "worde.com"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "worde.com"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningPropertiesPath != null) {
            create("release") {
                keyAlias = requiredReleaseSigningProperty("keyAlias")
                keyPassword = requiredReleaseSigningProperty("keyPassword")
                storeFile = file(requiredReleaseSigningProperty("storeFile"))
                storePassword = requiredReleaseSigningProperty("storePassword")

                if (!storeFile!!.isFile) {
                    throw GradleException(
                        "Release keystore does not exist: ${storeFile!!.absolutePath}",
                    )
                }
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningPropertiesPath != null) {
                signingConfig = signingConfigs.getByName("release")
            }
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
