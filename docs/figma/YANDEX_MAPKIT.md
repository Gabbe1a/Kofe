# Yandex MapKit integration notes

Package: `yandex_mapkit_lite` + native `maps.mobile:4.4.0-lite` (must match plugin).

## Verified root cause (2026-07-11)

Logcat with `applicationId=ru.coffeemama.app`:

```text
Forbidden. Body :Invalid api key
Could not fetch .../mapkit2/init/2.x/random
```

Same key + `applicationId=com.foodsale.app.mobile` → **no Invalid api key** (key is valid).

Cabinet Key #3 restrictions include both packages, but Yandex still rejects
`ru.coffeemama.app` until restriction fully propagates, or create a new key
**without** Android package limits for this app.

May tariff updates affect DAU/pricing only — not the init API contract.

## Setup checklist

1. Key from MapKit Mobile SDK cabinet
2. `MAPKIT_API_KEY` in `android/local.properties`
3. `MainApplication`: `MapKitFactory.setApiKey` after `super.onCreate`
4. Manifest `android:name=".MainApplication"`
5. Do **not** bump native SDK above 4.4.0 with this Flutter plugin
   (4.22+ → `NoSuchMethodError: getMapObjects`)

## Venues

Mock addresses with real Rostov/Azov/Sochi coordinates in `mock_data.dart`.
