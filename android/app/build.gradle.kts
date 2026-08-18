import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesPath =
    providers.environmentVariable("LEXINEXO_KEY_PROPERTIES").orNull?.trim()?.takeIf { it.isNotEmpty() }
val releaseSigningProperties = Properties()
val testAdMobAppId = "ca-app-pub-3940256099942544~3347511713"
val testInterstitialAdUnitId = "ca-app-pub-3940256099942544/1033173712"
val releaseAdMobAppId =
    providers.environmentVariable("WORDE_ADMOB_APP_ID").orNull?.trim()?.takeIf { it.isNotEmpty() }
val releaseInterstitialAdUnitId =
    providers.environmentVariable("WORDE_ADMOB_INTERSTITIAL_ID").orNull?.trim()?.takeIf { it.isNotEmpty() }
val adMobAppIdPattern = Regex("^ca-app-pub-[0-9]{16}~[0-9]{10}$")
val adMobAdUnitIdPattern = Regex("^ca-app-pub-[0-9]{16}/[0-9]{10}$")

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
    if (releaseTasksInGraph.isNotEmpty()) {
        if (releaseAdMobAppId == null || !adMobAppIdPattern.matches(releaseAdMobAppId)) {
            throw GradleException(
                "Release AdMob App ID is missing or invalid. Set WORDE_ADMOB_APP_ID " +
                    "to the ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY value from AdMob.",
            )
        }
        if (
            releaseInterstitialAdUnitId == null ||
                !adMobAdUnitIdPattern.matches(releaseInterstitialAdUnitId)
        ) {
            throw GradleException(
                "Release interstitial AdMob unit ID is missing or invalid. Set " +
                    "WORDE_ADMOB_INTERSTITIAL_ID to ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY.",
            )
        }
        if (
            releaseAdMobAppId == testAdMobAppId ||
                releaseInterstitialAdUnitId == testInterstitialAdUnitId
        ) {
            throw GradleException("Google test AdMob IDs cannot be used in a release build.")
        }
        if (
            releaseAdMobAppId != null &&
                releaseInterstitialAdUnitId != null &&
                releaseAdMobAppId.substringAfter("ca-app-pub-").substringBefore('~') !=
                releaseInterstitialAdUnitId.substringAfter("ca-app-pub-").substringBefore('/')
        ) {
            throw GradleException(
                "WORDE_ADMOB_APP_ID and WORDE_ADMOB_INTERSTITIAL_ID must belong " +
                    "to the same AdMob publisher.",
            )
        }
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
        manifestPlaceholders["admobAppId"] = testAdMobAppId
        manifestPlaceholders["admobInterstitialId"] = testInterstitialAdUnitId
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
        debug {
            manifestPlaceholders["admobAppId"] = testAdMobAppId
            manifestPlaceholders["admobInterstitialId"] = testInterstitialAdUnitId
        }
        release {
            manifestPlaceholders["admobAppId"] = releaseAdMobAppId ?: "missing-admob-app-id"
            manifestPlaceholders["admobInterstitialId"] =
                releaseInterstitialAdUnitId ?: "missing-admob-interstitial-id"
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
