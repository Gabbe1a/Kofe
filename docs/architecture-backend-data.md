# Архитектура данных, пуши и сторона точки — рекомендации

**Дата:** 2026-07-09  
**Проект:** Кофе Мама Flutter  
**Связь:** `docs/TZ-Kofe-Mama-Flutter.md` v1.1  
**Статус:** решения зафиксированы в `docs/DECISIONS.md` (БД = Яндекс.Облако Postgres; пуши = RuStore)

---

## 1. Короткий вердикт

| Вопрос | Рекомендация |
|--------|----------------|
| База данных (прод, РФ) | **PostgreSQL в Яндекс.Облаке** (принято) — 152-ФЗ, оплата из РФ |
| База данных (прототип) | Локальный Postgres / mock, пока облако не поднято |
| Где хранит приложение | Локальный кэш + сервер как источник правды |
| Пуши Android (РФ) | **RuStore Push** (+ Universal SDK: RuStore/FCM/HMS), FCM не единственный канал |
| Пуши iOS | APNs через Apple Developer; закладывать in-app inbox как страховку |
| Firebase как БД заказов | **Не рекомендую** для РФ-прода (нестабильность + ПДн за рубежом) |
| Приложение для баристы | **Сначала не мобильное.** Web-панель / планшет в точке |
| Нужен ли ИП для пушей | **Нет** для техники пушей. Для эквайринга/договоров — отдельно с юристом/банком |
| Можно ли тестировать без Apple Developer | **Android + RuStore — да.** iOS real push — почти нет без аккаунта. UI статусов — без пушей |

---

## 2. Как данные живут в системе (3 слоя)

```text
┌─────────────────────┐
│  Flutter (клиент)   │  UI + локальный кэш
│  Hive / SharedPrefs │  city, venue, cart draft, token, last menu
└──────────┬──────────┘
           │ HTTPS / Realtime
┌──────────▼──────────┐
│  Backend API        │  Auth, orders, payments webhook, push send
│  (Supabase Edge /   │
│   Nest/FastAPI)     │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│  PostgreSQL         │  источник правды
│  + Storage (фото)   │
│  + Auth             │
└─────────────────────┘

Отдельно:
┌─────────────────────┐
│  Staff Web (точка)  │  смена статусов заказа, стоп-лист
└─────────────────────┘
┌─────────────────────┐
│  Alfa-Bank / эквайринг │  оплата, webhook → order.paid
└─────────────────────┘
┌─────────────────────┐
│  FCM + APNs         │  пуши клиенту (и опционально staff)
└─────────────────────┘
```

**Правило:** заказ, баланс бонусов, меню, статусы — **только на сервере**.  
Локально в телефоне — черновик корзины и оффлайн-кэш меню, чтобы UI не мигал.

---

## 3. Выбор БД — сравнение честно

### Вариант A — Supabase (Postgres) ← **рекомендую для старта**
**Плюсы:** быстрый старт, Auth (телефон/OTP можно связать), Realtime (статусы заказа «живые»), Storage для фото меню, Row Level Security, бесплатный/дешёвый tier.  
**Минусы:** сложную платёжную/бонусную логику всё равно пишете сами (Edge Functions).  
**Когда:** вы один/маленькая команда, хотите быстрее дойти до рабочего MVP.

### Вариант B — Firebase (Firestore + Auth + FCM)
**Плюсы:** пуши из коробки, просто для мобилки.  
**Минусы:** заказы/отчёты/роли точки на документной БД неудобнее; сложные запросы и админка сети хуже, чем SQL.  
**Когда:** если почти нет серверной логики. У вас логика заказов/точек/статусов — SQL удобнее.

### Вариант C — Свой backend (NestJS/FastAPI) + Postgres + Redis
**Плюсы:** полный контроль, проще под Alfa webhook, бонусы, мультиточечность.  
**Минусы:** дольше и дороже в разработке/девопсе.  
**Когда:** сеть растёт, нужна кастомная интеграция с 1С/iiko/r_keeper.

### Практичный путь
1. **Сейчас:** Supabase (Postgres) + Edge Functions под оплату/пуши.  
2. **Потом:** при необходимости вынести API в свой сервис, БД остаётся Postgres.

Я бы **не** начинал с «чистого Firebase как единственной БД заказов» для сети кофеен.

---

## 4. Что хранить: сущности и ключевые поля

### 4.1. Справочники сети
| Таблица | Поля (минимум) |
|--------|----------------|
| `cities` | id, name, is_active, sort |
| `venues` | id, city_id, short_name, full_address, phone, lat, lng, timezone, is_active |
| `venue_hours` | venue_id, days_mask / day_from-to, open_time, close_time |
| `categories` | id, parent_id?, title, image_url, sort, is_active |
| `products` | id, category_id, title, description, image_url, weight_g?, base_price, is_active, has_nutrition |
| `product_nutrition` | product_id, proteins, fats, carbs, kcal |
| `modifier_groups` | id, product_id, title, min_select, max_select, required, sort |
| `modifier_options` | id, group_id, title, price_delta, is_default, sort |
| `banners` / `promo_slides` | id, title, body, image_url, cta_url, sort, active_from/to |
| `upsells` | product_id, sort (или rule-based later) |

### 4.2. Пользователи и лояльность
| Таблица | Поля |
|--------|------|
| `users` | id, phone (unique, locked), name, email?, birth_date?, created_at |
| `user_devices` | user_id, fcm_token, platform (ios/android), updated_at |
| `bonus_accounts` | user_id, balance |
| `bonus_ledger` | id, user_id, order_id?, delta, reason (earn/spend/promo/manual), created_at |
| `payment_methods` | id, user_id, provider_ref, brand, last4, is_default (PAN не хранить!) |

### 4.3. Заказы (ядро)
| Таблица | Поля |
|--------|------|
| `orders` | id, number (человекочитаемый), user_id, venue_id, status, order_type=`takeaway`, pickup_at, comment, promo_code?, address_confirmed, subtotal, discount, bonus_spent, total, ready_estimate_at, paid_at, created_at, updated_at |
| `order_items` | id, order_id, product_id, title_snapshot, qty, unit_price, line_total |
| `order_item_modifiers` | order_item_id, group_title, option_title, price_delta |
| `order_status_events` | id, order_id, from_status, to_status, actor_type (system/staff/payment), actor_id?, created_at |
| `payments` | id, order_id, provider=`alfabank`, external_id, amount, status, raw_webhook_json, created_at |
| `reviews` | id, order_id, food_rating, service_rating, text?, created_at |
| `promo_codes` | code, type, value, active, limits… |
| `notifications_inbox` | id, user_id, type, title, body, order_id?, read_at?, created_at |

### 4.4. Сторона точки (даже если web)
| Таблица | Поля |
|--------|------|
| `staff_users` | id, name, phone/email, role (`barista`/`manager`/`admin`) |
| `staff_venue_access` | staff_id, venue_id |
| `product_stop_list` | venue_id, product_id, is_stopped, updated_at |
| `venue_settings` | venue_id, default_cook_minutes (15), auto_confirm_on_pay bool |

---

## 5. Статусы заказа и пуши

### 5.1. Машина статусов (клиент видит)

```text
draft (только локально в корзине)
  → pending_payment   (создали order, ждём оплату)
  → confirmed         (оплата OK / точка подтвердила)  + estimate ~15 мин
  → preparing         (бариста: готовится)
  → ready             (приготовлен / можно забирать)
  → issued            (выдан)
  → completed         (закрыт в истории; часто = issued+время)
  → cancelled         (отмена/не оплачен/отказ точки)
  → refunded          (возврат) — заложить сразу
```

Соответствие пушам из скринов:
| Статус | Текст пуша (пример) |
|--------|---------------------|
| confirmed | «…заказ №N подтвержден» |
| preparing | «…заказ №N готовится» |
| ready | «…заказ №N приготовлен» |
| issued | «Заказ №N выдан» |
| promo | маркетинговые (отдельный type) |

### 5.2. Кто меняет статус

| Событие | Кто | Как |
|---------|-----|-----|
| Заказ создан | система | после «Оплатить» |
| pending → confirmed | **платёжный webhook** (+ опционально авто) | Alfa success |
| confirmed → preparing → ready → issued | **сотрудник точки** | Staff Web кнопки |
| estimate +15 мин | система при confirmed | `ready_estimate_at = now+15m` (настройка venue) |
| пуш клиенту | система | на каждый `order_status_events` insert |

Бариста **не обязан** иметь отдельное мобильное приложение. Ему нужен экран:
- список активных заказов точки;
- кнопки статусов;
- звук нового заказа;
- стоп-лист «закончился сироп».

Это идеально как **PWA / web на планшете** у кассы.

---

## 6. Пуши: что правда, что миф

### Миф: «нужен ИП, чтобы одобрили пуши»
**Неверно.**  
- **Android:** Google Firebase — обычный Google-аккаунт.  
- **iOS:** нужен **Apple Developer Program** (платный аккаунт разработчика). Его оформляют на **имя физлица** или компанию. Российский **ИП** для этого не обязателен.  
(ИП может понадобиться для юр. договора с эквайрингом/магазином приложений как бизнес — это отдельно от «технического» пуша.)

### Что реально нужно для iOS push
1. Apple Developer Account.  
2. App ID + Push capability.  
3. APNs key → в FCM.  
4. Сборка через Xcode / Codemagic / и т.п.  
5. Разрешение пользователя на уведомления в runtime.

### Как тестировать **без** Apple Developer сейчас
| Что | Как |
|-----|-----|
| Экран «Уведомления» в приложении | Писать строки в `notifications_inbox` — UI полный |
| Смена статусов | Staff web / mock admin → Realtime обновляет заказ |
| Android push | Реальный FCM на Android-телефон |
| iOS push | Отложить до Developer Account / TestFlight |
| Локальные уведомления | Можно имитировать таймер «через 15 мин» на устройстве (не замена серверным) |

**Вывод:** отсутствие ИП/Apple Developer **не блокирует** разработку UI, БД, статусов и Android. Блокирует только **реальные iOS remote push** и публикацию в App Store.

---

## 7. Нужно ли мобильное приложение баристе?

### Моё мнение: **на старте — нет**

| Подход | Плюсы | Минусы |
|--------|-------|--------|
| **Staff Web / планшет** (рекомендую) | Быстрее, дешевле, одна кодовая база админки, большой экран кухни | Нужен браузер/планшет в точке |
| Отдельное Flutter staff-app | Удобно «в кармане» | Второй продукт: auth ролей, пуши staff, поддержка, ревью сторов |
| WhatsApp/Telegram бот точке | Очень дёшево как временный костыль | Плохо масштабируется, нет стоп-листа/аналитики |

**Этап 1:** клиентское Flutter-приложение + Staff Web.  
**Этап 2 (если попросят):** staff mobile или Telegram-miniapp для смены статуса.

Пуш баристе («новый заказ!») на web делается через:
- звук + fullscreen на планшете;
- или Telegram-бот в чат точки (часто хватает сети).

---

## 8. Функции, которые вы могли не озвучить, но обычно нужны

### Must-have рядом с ТЗ (иначе боль в проде)
1. **Стоп-лист по точке** — «закончился банановый сироп» → товар скрыт/нельзя заказать.  
2. **Часы работы точки** + нельзя выбрать pickup time вне графика.  
3. **Номер заказа на экране** крупно (для выдачи).  
4. **Идемпотентность оплаты** — повторный webhook не создаёт два заказа.  
5. **Отмена / неуспешная оплата** — статус cancelled, корзина/повтор.  
6. **Роли staff** — бариста только своя точка; админ сети — все.  
7. **Аудит статусов** — кто и когда нажал «приготовлен».  
8. **Контент меню с админки** — цены/фото без релиза приложения.  
9. **Версия приложения / force update** — если сломали API.  
10. **Согласие на пуши и маркетинг** (у вас уже legal на auth-экране).

### Should-have
11. Возврат / частичный refund.  
12. Причины отмены.  
13. «Заказ скоро сгорит» если ready > N минут.  
14. Отчёт точки за смену (кол-во заказов, сумма).  
15. Мультифото/модификаторы «недоступны на этой точке».  
16. Rate-limit на SMS/OTP.  
17. Антифрод промокодов.  
18. Deep link из пуша сразу в детали заказа.

### Later
19. Интеграция с iiko / r_keeper / 1С.  
20. Склад/техкарты.  
21. Курьеры (у вас доставки нет — не нужно).  
22. Отдельное staff mobile app.

---

## 9. Что хранить только локально в Flutter

| Данные | Где | Зачем |
|--------|-----|-------|
| access/refresh token | Secure Storage | сессия |
| selected city/venue | SharedPreferences | быстрый старт |
| draft cart | Hive/Isar | не потерять при убийстве app |
| save_comment flag + text | local | как в ТЗ |
| cached menu snapshot | Hive + TTL | оффлайн/скорость |
| fcm token | local + sync server | пуши |
| onboarding/promo seen | local | |

Сервер всегда может пересчитать цену при checkout (защита от подмены).

---

## 10. Минимальный API-контракт (для ТЗ backend)

```text
Auth:   POST /auth/phone  POST /auth/verify
User:   GET/PATCH /me
Catalog:GET /cities  GET /venues?city=  GET /menu?venue=
Cart:   POST /orders/quote   (пересчёт цен/промо)
Orders: POST /orders  GET /orders  GET /orders/:id
Pay:    POST /orders/:id/pay  POST /payments/webhook/alfa
Review: POST /orders/:id/review
Staff:  GET /staff/orders?venue=  POST /staff/orders/:id/status
Admin:  CRUD menu, stop-list, banners
Push:   internal on status change → FCM
```

Realtime (Supabase channel `orders:user_id=…`) — чтобы экран заказа обновлялся без pull-to-refresh.

---

## 11. Этапы внедрения (реалистично)

| Этап | Что | Пуши |
|------|-----|------|
| 0 | Flutter UI + mock API | in-app inbox fake |
| 1 | Supabase schema + auth phone | inbox из БД |
| 2 | Orders + staff web статусы | Realtime в клиенте |
| 3 | Alfa webhook | confirmed автоматом |
| 4 | FCM Android | реальные пуши |
| 5 | Apple Developer + APNs | iOS пуши |
| 6 | Бонусы ledger + стоп-лист | — |

---

## 12. Моё мнение по вашему тексту — прямо

1. **База:** берите **Postgres (Supabase)** — для заказов/точек/статусов это правильнее Firestore.  
2. **Бариста в мобильном приложении сейчас не нужен** — сделайте web-экран точки; так вы не раздуваете scope.  
3. **Пуши** — закладываем в архитектуру сразу (`user_devices`, статусы → send), но **не стопорим UI** из‑за отсутствия Apple Developer / ИП.  
4. **ИП ≠ условие пушей.** Путаница частая; для iOS нужен Developer Account, для эквайринга/договора с банком — уже юр.вопросы отдельно.  
5. Вы хорошо описали ручные статусы точки — это **ядро**, его надо моделировать как `order_status_events`, а не «просто поле status».  
6. Самое часто забываемое: **стоп-лист**, **часы работы + слоты времени**, **webhook оплаты**, **роли staff**, **не хранить карты у себя**.

---

## 13. Актуально для РФ (июль 2026) — Firebase / облака / пуши

> Сводка по открытым источникам на момент 2026-07. Санкции и блокировки меняются — перед продом перепроверить.

### 13.1. Firebase / Google Cloud
| Факт | Практический вывод |
|------|-------------------|
| Firebase **не «официально убит»** для всех, но **нестабилен** в РФ (Firestore/Auth часто требуют VPN; жалобы разработчиков с 2023+) | **Не строить ядро БД заказов на Firebase** |
| Оплата Google Cloud из РФ — через костыли/нерезидентов, риск отключения биллинга | Плохая опора для прод-бизнеса кофейни |
| FCM как единственный Android-push в 2026 в РФ часто называют «лотереей» | Нужен **мульти-канал** |

### 13.2. Что использовать для пушей в РФ
**Android (основная аудитория сети):**
1. **RuStore Push** — официальная альтернатива FCM, доки на русском, API совместим по духу с FCM.  
   Docs: https://www.rustore.ru/help/sdk/push-notifications  
2. **RuStore Universal Push SDK** — один слой на **RuStore + FCM + HMS** (и APNs на стороне API).  
3. **Huawei HMS Push** — для Honor/Huawei без GMS (заметная доля в РФ).  
4. FCM — опциональный fallback, не единственный канал.

**iOS:**
- Канал = **APNs** (через Apple Developer).  
- Отдельно: в июне 2026 Apple снимал ряд российских приложений (VK/Max) и резал им пуши — это **не значит**, что любое новое app из РФ автоматически без пушей, но риск App Store / compliance выше; закладывать **Android-first** и in-app inbox обязательно.

**Независимо от пушей:**
- Экран «Уведомления» + Realtime статуса заказа в приложении — must-have (работает без FCM).

### 13.3. База данных и 152-ФЗ
Телефон, имя, история заказов = **персональные данные**.  
По 152-ФЗ первичная запись ПДн граждан РФ — **на территории РФ**.

| Вариант | Оценка для «Кофе Мама» |
|---------|-------------------------|
| **Yandex Cloud Managed PostgreSQL** | **ПРИНЯТО** для прода — ЦОД в РФ, 152-ФЗ, оплата |
| Selectel / VK Cloud | запасной вариант, если понадобится смена провайдера |
| Supabase (зарубежные регионы) | только прототип, не прод-ПДн |
| Firebase Firestore | не используем как БД заказов |

**Принято (2026-07-09):**  
- Prod: **Postgres в Яндекс.Облаке** + API.  
- Пуши: **RuStore Push** (+ HMS/FCM по необходимости), iOS APNs отдельно.  
- См. `docs/DECISIONS.md`.

### 13.4. Магазины приложений
- **RuStore** — обязательный канал дистрибуции Android в РФ (и для нормальной работы RuStore Push).  
- Google Play — по возможности, но не единственный.  
- App Store — отдельный трек (Developer Account, модерация, геополитика).

### 13.5. Итог одной фразой для РФ
Не опирайтесь на Firebase как на «всё в одном».  
**Postgres в российском облаке + RuStore Push (+ HMS) + in-app статусы + Staff Web** — устойчивая схема под санкции и 152-ФЗ.

Если ок с этим направлением — следующим шагом могу добавить в репозиторий черновик SQL-схемы (`docs/schema.sql`) и короткий ADR «почему Postgres в РФ-облаке, а не Firebase».
