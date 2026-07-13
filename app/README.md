# Кофе Мама — Flutter UI skeleton

Мобильное приложение самовывоза **«С собой»** по ТЗ v1.2 + AURA (Jannat).

## Package

- Android `applicationId` / namespace: **`ru.coffeemama.app`**
- Dart package: `kofe_mama`

## Стек

- Flutter + **Riverpod** + **go_router** (4 таба)
- Тема AURA: Manrope + Nunito Sans, forest/cream
- Данные фазы 1: **mock** + локальные PNG в `assets/images/products/`
- Зависимости временно через `third_party/` (pub.dev зависал)

## Запуск

```bash
cd app
flutter pub get --offline
flutter run
```

Flow: Splash → город → точка → promo → Shell (Меню с Home peek + каталог 2-col + PDP).

## Ассеты

Уже сгенерированные PNG в `assets/images/products/` (фон можно вырезать позже вручную). Новые MCP-картинки не генерируем, пока не попросите.

## Вне scope сейчас

Яндекс.Облако, RuStore Push, Alfa WebView, MapKit, Staff Web.
