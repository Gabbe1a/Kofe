# Кофе Мама

<p align="center">
  <img src="docs/assets/kofe-mama-cover.png" alt="Холодный кофейный напиток на песочном фоне" width="100%" />
</p>

<p align="center">
  <strong>Мобильное приложение кофейни, API каталога и Staff Web для управления сетью.</strong>
</p>

<p align="center">
  <code>Flutter</code> · <code>FastAPI</code> · <code>PostgreSQL</code> · <code>Yandex Object Storage</code> · <code>ЮKassa (тестовый режим)</code>
</p>

## Что уже есть

- Каталог, поиск, промо, выбор города и точки самовывоза.
- Карточка товара с размерами, кофе, молоком, сиропами и серверным расчётом стоимости.
- Корзина с локальными ценами точки, промокодом, комментарием и оформлением заказа.
- Тестовая redirect-оплата через ЮKassa: приложение открывает защищённую страницу провайдера, а статус сверяется на сервере.
- Staff Web (`/admin`): меню, точки, локальные цены и доступность, стоп-лист, очередь заказов, акции и команда.
- Медиа товаров и баннеров через Object Storage вместо путей к локальным Flutter-asset'ам.

## Структура

```text
app/         Flutter-клиент для Android/iOS
backend/     FastAPI, PostgreSQL-схема, миграции и VPS-инструменты
docs/        ТЗ, решения, архитектура и дизайн-материалы
docs/assets/ Оригинальные публичные материалы репозитория
```

## Локальный запуск

### Backend

```powershell
Copy-Item backend/.env.example backend/.env.vps.local
# Заполните только локальный backend/.env.vps.local — этот файл игнорируется Git.
Set-Location backend
docker compose up --build
```

API будет доступен на `http://localhost:8080`; Staff Web — на `http://localhost:8080/admin`.

### Flutter

```powershell
Set-Location app
Copy-Item android/local.properties.example android/local.properties
# Добавьте MAPKIT_API_KEY в android/local.properties.
flutter pub get
flutter run --dart-define=API_BASE_URL=http://YOUR_API_HOST
```

## Конфигурация и безопасность

- Реальные ключи ЮKassa, Object Storage, VPS и MapKit не хранятся в Git.
- `backend/.env.example` и `app/android/local.properties.example` — только шаблоны.
- Для production обязателен HTTPS-домен: он нужен для защищённого Staff Web, webhook ЮKassa и будущих App Links.
- До завершения пользовательской авторизации проект остаётся MVP: не используйте его для реальных платежей и персональных данных.

Подробности — в [SECURITY.md](SECURITY.md), [документации](docs/README.md) и [архитектуре](docs/architecture-backend-data.md).

## Лицензия

Лицензия для публичного распространения пока не выбрана. Все права сохраняются за владельцем проекта.
