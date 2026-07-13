package ru.coffeemama.app

/**
 * MapKit API key is supplied only from android/local.properties via BuildConfig.
 */
object MapKitSecrets {
    val API_KEY: String
        get() {
            val fromBuild = BuildConfig.MAPKIT_API_KEY.trim()
            if (fromBuild.isNotBlank()) return fromBuild
            throw IllegalStateException(
                "MAPKIT_API_KEY is missing. Set it in android/local.properties before running the app.",
            )
        }

    const val LOCALE: String = "ru_RU"
}
