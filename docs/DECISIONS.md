# Принятые решения (ADR / Decision Log)

**Проект:** Кофе Flutter
**Обновлено:** 2026-07-09

---

## D-001 — База данных и хостинг (ПРИНЯТО)

| | |
|--|--|
| **Решение** | Прод-БД: **PostgreSQL в Яндекс.Облаке** (Managed PostgreSQL) |
| **Почему** | РФ, 152-ФЗ (ПДн в РФ), стабильная оплата, не опираться на Firebase/зарубежный SaaS как единственный прод |
| **Прототип** | До создания облака можно локальный Postgres / mock в Flutter |
| **API** | Свой backend рядом (Cloud Functions / VM / Serverless Containers) — детали на этапе backend |
| **Не используем как прод-БД** | Firebase Firestore; зарубежный Supabase как единственное хранилище ПДн |

---

## D-002 — Пуш-уведомления (ПРИНЯТО)

| | |
|--|--|
| **Android (РФ)** | **RuStore Push** (+ по возможности Universal: RuStore / FCM / HMS) |
| **iOS** | APNs (когда будет Apple Developer) |
| **Обязательная страховка** | In-app экран «Уведомления» + realtime/poll статуса заказа (работает без пуша) |
| **Staff / бариста** | Не мобильные пуши на старте → **Staff Web** на планшете в точке |
| **ИП** | Не требуется для подключения пушей |

### Статус RuStore (факт на 2026-07-09)
- [x] Регистрация в RuStore Console (VK ID)
- [x] Роль: **Владелец**
- [x] Тип аккаунта: **Физлицо**
- [x] Создано приложение в консоли: внутреннее имя **«Кофе»**
- [x] Тип: **Универсальное**; монетизация UI был locked (по факту бесплатное приложение)
- [ ] Package name зафиксировать при создании Flutter-проекта (должен совпасть с консолью)
- [ ] Push-проект / ключи — **когда будет Flutter-сборка** (не блокер UI)
- [ ] Загрузка версии / витрина — после первой APK
- [ ] HMS — вторым шагом при необходимости Honor/Huawei
- [ ] Apple Developer + APNs — отдельный этап

**Важно:** пуши подключаются **в разработке** (SDK + тестовый APK), не «только после публикации». Публикация в RuStore для первого теста пуша не обязательна.

---

## D-003 — Модель заказа (ПРИНЯТО ранее)

Только самовывоз **«С собой»**. Доставки и зала в приложении нет.

---

## D-004 — Дизайн (ПРИНЯТО)

Источник: `ref/` + AURA пакет в `teya-memory/design/`.  
PRIMARY: Jannat «Smooth Out Your Everyday» (карусель peek + зелёная дуга + PDP).  
Палитра: forest/emerald/sage/cream/caramel. Не black+cyan старого приложения.

---

## D-005 — Сторона точки / бариста (ПРИНЯТО)

На старте: **Staff Web**, не отдельное мобильное staff-app.

---

## D-006 — Android package (ПРИНЯТО)

`applicationId` / namespace: **`ru.coffeemama.app`**  
(Dart package name: `kofe_mama`, каталог `app/`).  
В RuStore Console сверить/прописать тот же package при подключении Push SDK.

---

## D-007 — Карта точек MVP (ПРИНЯТО)

| | |
|--|--|
| **MVP** | Интерактивный `VenueMap` на lat/lng пинах (branded canvas, pan/pinch, sync pin↔list) — без native SDK key |
| **Почему сейчас** | Yandex MapKit / `flutter_map`+OSM требуют ключ или нестабильный pub.dev в среде; web Playwright не должен блокироваться |
| **Production target** | **Yandex MapKit** за тем же API виджета `VenueMap` (пины бренда, тёмная стилизация по ТЗ) |
| **Данные** | `Venue.lat` / `Venue.lng` в mock; позже — из Postgres |

Файлы: `app/lib/features/venues/venue_map.dart`, `venues_screen.dart`, onboarding `venue_screen.dart`.

---

## D-008 — Home category arc IA + geometry (ПРИНЯТО)

| | |
|--|--|
| **Геометрия** | Forest half-disk кодом (`CustomPainter`), иконки на верхней дуге, featured-карусель **внутри** зелёной чаши |
| **IA дуги** | 4 слота: **Кофе · Холодные · Чаи · Авторские** (`coffee` / `signature_cold` / `tea` / `signature_hot`) |
| **Не на дуге** | Выпечка / bakery / goods — убраны из Home chord |
| **Иконки** | Inline Path glyphs, не Material `Icons.bakery_dining` |
| **Bottom nav** | Sage bar с вогнутым верхним краем (`_ConcaveSageBarPainter`) |
| **MCP** | Не нужен для шейпа дуги; только если позже понадобятся illustrated cutout-иконки |

Файлы: `app/lib/features/menu/menu_screen.dart`, `app/lib/data/mock/mock_data.dart`, `app/lib/core/router/app_router.dart`.

---

## Следующие шаги (очередь)

1. ~~Flutter skeleton по ТЗ + AURADESIGN (UI, mock data).~~ **done** — см. `app/`  
2. ~~Зафиксировать `applicationId` / package.~~ **`ru.coffeemama.app`**  
3. ~~Карта точек MVP (пины + sync).~~ **done** — D-007; MapKit — когда будет ключ  
4. ~~Jannat Home half-disk + coffee-only arc.~~ **done** — D-008  
5. Яндекс.Облако: каталог, Managed PostgreSQL, черновик `schema.sql`.  
6. Подключить RuStore Push SDK на тестовом Android.  
7. Staff Web статусов заказа.  
8. Alfa webhook / оплата.  
9. iOS / APNs по готовности.  
10. Заменить `VenueMap` canvas → Yandex MapKit.
