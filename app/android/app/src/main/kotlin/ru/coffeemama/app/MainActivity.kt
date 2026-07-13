package ru.coffeemama.app

import io.flutter.embedding.android.FlutterActivity

/**
 * Lifecycle onStart/onStop for MapKit is handled by yandex_mapkit_lite
 * (ActivityAware). Do not double-call MapKitFactory.onStop here — that can
 * leave the map in a white-grid state after tab switches.
 */
class MainActivity : FlutterActivity()
