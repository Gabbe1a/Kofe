package ru.coffeemama.app

import android.app.Application
import android.util.Log
import com.yandex.mapkit.MapKitFactory

/**
 * MapKit init per current Yandex docs:
 * setApiKey in Application.onCreate before any map usage.
 * Native initialize() is performed by yandex_mapkit_lite plugin.
 */
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val key = MapKitSecrets.API_KEY
        Log.i(
            "MapKitInit",
            "package=$packageName keyLen=${key.length} keyPrefix=${key.take(8)}…",
        )
        MapKitFactory.setLocale(MapKitSecrets.LOCALE)
        MapKitFactory.setApiKey(key)
    }
}
