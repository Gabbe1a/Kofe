# Kofe Mama backend (MVP)

Docker Compose runs PostgreSQL 16 and FastAPI. PostgreSQL is private; API is
published on ports **80** and **8080**.

## Configuration

Copy `.env.example` to `.env` and replace every placeholder. The real file is
ignored by Git. It contains database, Object Storage and first-admin secrets.

- `S3_*` and `MEDIA_BASE_URL` enable image upload and public HTTPS media URLs.
- `STAFF_TOKEN_SECRET` signs the staff sessions; use a unique random value of at
  least 32 characters.
- `ADMIN_BOOTSTRAP_EMAIL` and `ADMIN_BOOTSTRAP_PASSWORD` create the first admin
  at app startup only when both are set. Change the password operationally after
  the first login; never commit it.

The bucket itself is intentionally not created by the application. Create a
private-admin/public-read (or CDN-backed) Yandex Object Storage bucket first,
then give the API service account access only to that bucket.

## First start

```bash
cd backend
docker compose up -d --build
curl http://127.0.0.1:8080/health
```

For a new database, Compose executes schema, seed and all numbered migrations
automatically. Existing databases keep their volume, so apply each migration
once from the database container in this order:

```bash
docker compose exec -T db psql -U kofe -d kofe_mama -f /docker-entrypoint-initdb.d/03_orders_venue.sql
docker compose exec -T db psql -U kofe -d kofe_mama -f /docker-entrypoint-initdb.d/04_syrup_modifiers.sql
docker compose exec -T db psql -U kofe -d kofe_mama -f /docker-entrypoint-initdb.d/05_catalog_media.sql
docker compose exec -T db psql -U kofe -d kofe_mama -f /docker-entrypoint-initdb.d/06_order_core.sql
docker compose exec -T db psql -U kofe -d kofe_mama -f /docker-entrypoint-initdb.d/07_yookassa.sql
```

## Media and staff admin

`tools/upload_media.py` transfers only approved local product and promo PNGs,
converting them to delivery-ready WebP (quality 82, transparency preserved).
Admin uploads follow the same rule even when the original is PNG or JPEG. It
deliberately omits the missing peach tea and mojito files: those products return
`imageUrl: null` until a real approved image is uploaded.

After storage is configured, open `http://<server>/admin`. The role-protected
admin API supports product price/content, promo content, media upload, and the
venue stop-list. `admin` manages everything, `manager` manages content only for
assigned venues' stop-lists, and `barista` changes only its assigned venues'
stop-list.

## Mobile API contract

- `GET /menu?venue_id=…` returns only active, non-stopped products for a venue.
- API media fields are `imageUrl`; legacy `assets/images/...` paths are never
  returned after `migrate_catalog_media.sql`.
- `POST /orders/quote` and `POST /orders` recompute totals and validate all
  required modifiers server-side. Orders are idempotent by `idempotency_key`.

## YooKassa test flow

Once test credentials are in the ignored `.env`, the client calls
`POST /orders/{id}/payment` and opens the returned `confirmationUrl` in the
external browser. The endpoint creates one idempotent redirect payment per
order. A return from the browser is not treated as successful payment.

Configure YooKassa to deliver webhooks to
`https://<public-https-domain>/webhooks/yookassa`. The API fetches the payment
from YooKassa before setting the order to `confirmed`; the barista then moves it
through `preparing → ready → issued` via `/admin/orders/{id}/status`. An IP-only
server is suitable for development API traffic but not verified Android App
Links or production payment webhooks: use a public HTTPS domain first.

The current mobile build can continue to use its configured base URL:

```bash
flutter run --dart-define=API_BASE_URL=http://94.249.239.210:8080
```
