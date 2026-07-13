# Документация проекта «Кофе» (rebrand / Flutter)

Зафиксированное состояние на **2026-07-09** · ТЗ **v1.2** · **54** скрина.

## Главные документы

| Файл | Назначение |
|------|------------|
| [`TZ-Kofe-Mama-Flutter.md`](./TZ-Kofe-Mama-Flutter.md) | **Подробное ТЗ v1.2** — функционал 1:1 |
| [`DECISIONS.md`](./DECISIONS.md) | **Принятые решения:** Яндекс.Облако, RuStore Push, Staff Web |
| [`architecture-backend-data.md`](./architecture-backend-data.md) | Схема данных, статусы, пуши, РФ |
| [`screen-inventory.md`](./screen-inventory.md) | Inventory **54** скриншотов |
| [`missing-screens-checklist.md`](./missing-screens-checklist.md) | Пробелы / что закрыто досъёмкой |
| [`artifacts/`](./artifacts/) | Копии ключевых документов |

## Дизайн

| Путь | Назначение |
|------|------------|
| `teya-memory/design/AURADESIGN.md` | Дизайн-контракт (Jannat PRIMARY) |
| `teya-memory/design/index.html` | Preview Home + PDP |
| `ref/` | Pinterest-референсы |

## Ключевые продуктовые факты

- Только самовывоз **«С собой»**.
- Auth: телефон → Telegram / Макс / SMS.
- Эквайринг: **Alfa-Bank** WebView.
- Статусы: подтвержден → готовится → приготовлен → выдан (+ ~15 мин).
- **БД:** PostgreSQL в **Яндекс.Облаке**.
- **Пуши Android:** RuStore Push; консоль: приложение **«Кофе»** создано.
- Отзыв: еда + сервис отдельно.
- Бариста: Staff Web (не mobile на старте).

## Очередь работ

1. ~~Flutter skeleton (UI + mock) по ТЗ + AURA~~ — **Flutter UI skeleton done** (`app/`)  
2. ~~Package name = RuStore~~ — **`ru.coffeemama.app`**  
3. Яндекс.Облако Postgres + `schema.sql`  
4. RuStore Push SDK на тестовом Android  
5. Staff Web статусов  
6. Оплата Alfa  

## Как пользоваться

1. Фичи UI — **ТЗ v1.2**.  
2. Инфра/пуши/БД — **DECISIONS** + architecture.  
3. Дизайн — **AURADESIGN**.  
