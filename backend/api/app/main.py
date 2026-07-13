from __future__ import annotations

import base64
import hashlib
import hmac
from io import BytesIO
import json
import os
import secrets
import time
import uuid
from contextlib import contextmanager
from decimal import Decimal, ROUND_DOWN
from pathlib import Path
from typing import Any, Iterator

import psycopg
from fastapi import Depends, FastAPI, File, Header, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel, Field
from PIL import Image, UnidentifiedImageError
from psycopg.rows import dict_row

DATABASE_URL = os.environ.get("DATABASE_URL", "")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL must be configured through the runtime environment")
MEDIA_BASE_URL = os.environ.get('MEDIA_BASE_URL', '').rstrip('/')
STAFF_TOKEN_SECRET = os.environ.get('STAFF_TOKEN_SECRET', '')

app = FastAPI(title="Kofe Mama API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event('startup')
def bootstrap_admin_from_environment() -> None:
    """Create the first admin only when all three bootstrap variables are set.

    The password never enters SQL files or source control. Later edits happen
    through a restricted operational procedure, not through this endpoint.
    """
    email = os.environ.get('ADMIN_BOOTSTRAP_EMAIL', '').strip().lower()
    password = os.environ.get('ADMIN_BOOTSTRAP_PASSWORD', '')
    if not email or not password:
        return
    with db() as conn:
        conn.execute(
            '''INSERT INTO staff_users (id, email, password_hash, role)
               VALUES (%s, %s, %s, 'admin') ON CONFLICT (email) DO NOTHING''',
            (f'staff_{uuid.uuid4().hex}', email, hash_password(password)),
        )


@contextmanager
def db() -> Iterator[psycopg.Connection]:
    conn = psycopg.connect(DATABASE_URL, row_factory=dict_row)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def money(value: Any) -> float:
    return float(value) if value is not None else 0.0


BONUS_ACCRUAL_RATE = Decimal('0.05')
MINIMUM_CASH_PAYMENT = Decimal('1.00')


def earned_bonus_points(payment_total: Any) -> int:
    """Five percent of the rouble payment, rounded down to whole points."""
    value = Decimal(str(payment_total or 0)) * BONUS_ACCRUAL_RATE
    return int(value.to_integral_value(rounding=ROUND_DOWN))


def maximum_bonus_points(order_total: Any) -> int:
    """Allow bonuses to cover everything except the final one rouble."""
    value = Decimal(str(order_total or 0)) - MINIMUM_CASH_PAYMENT
    if value <= 0:
        return 0
    return int(value.to_integral_value(rounding=ROUND_DOWN))


def media_url(object_key: str | None) -> str | None:
    if not object_key or not MEDIA_BASE_URL:
        return None
    return f'{MEDIA_BASE_URL}/{object_key.lstrip("/")}'


class CartModifierInput(BaseModel):
    group_id: str
    option_id: str


class CartItemInput(BaseModel):
    product_id: str
    qty: int = Field(ge=1, le=99)
    size_id: str | None = None
    modifiers: list[CartModifierInput] = Field(default_factory=list)


class QuoteRequest(BaseModel):
    venue_id: str
    items: list[CartItemInput] = Field(min_length=1)
    promo_code: str | None = None
    bonus_points: int = Field(default=0, ge=0)


class CreateOrderRequest(QuoteRequest):
    address_confirmed: bool
    comment: str | None = Field(default=None, max_length=500)
    pickup_at: str | None = None
    idempotency_key: str = Field(min_length=8, max_length=128)
    user_id: str = 'u_demo'  # replaced by the authenticated subject in phase 2 auth.


class ReviewRequest(BaseModel):
    food_rating: int = Field(ge=1, le=5)
    service_rating: int = Field(ge=1, le=5)
    text: str | None = Field(default=None, max_length=1000)


class StaffLoginRequest(BaseModel):
    email: str
    password: str = Field(min_length=8, max_length=256)


class ProductAdminUpdate(BaseModel):
    category_id: str | None = None
    title: str | None = Field(default=None, min_length=1, max_length=160)
    description: str | None = Field(default=None, max_length=2000)
    price: float | None = Field(default=None, ge=0)
    image_media_id: str | None = None
    weight_label: str | None = Field(default=None, max_length=80)
    featured: bool | None = None
    is_active: bool | None = None
    sort_order: int | None = None


class ProductAdminCreate(BaseModel):
    id: str = Field(pattern=r'^[a-z0-9_]{3,64}$')
    category_id: str
    title: str = Field(min_length=1, max_length=160)
    description: str = ''
    price: float = Field(ge=0)
    weight_label: str | None = None
    featured: bool = False
    image_media_id: str | None = None
    sort_order: int = 0


class PromoAdminUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=160)
    body: str | None = Field(default=None, max_length=1000)
    image_media_id: str | None = None
    is_active: bool | None = None
    sort_order: int | None = None


class PromoAdminCreate(BaseModel):
    id: str = Field(pattern=r'^[a-z0-9_]{3,64}$')
    title: str = Field(min_length=1, max_length=160)
    body: str = Field(default='', max_length=1000)
    cta_url: str | None = Field(default=None, max_length=500)
    image_media_id: str | None = None
    sort_order: int = 0
    is_active: bool = True


class StopListUpdate(BaseModel):
    is_stopped: bool


class VenueProductOverrideInput(BaseModel):
    price: float | None = Field(default=None, ge=0)
    is_available: bool = True


class VenueModifierOverrideInput(BaseModel):
    is_available: bool = True
    price_delta: float | None = Field(default=None, ge=0)


class CityAdminInput(BaseModel):
    id: str = Field(pattern=r'^[a-z0-9_]{3,64}$')
    name: str = Field(min_length=1, max_length=120)
    sort_order: int = 0
    is_active: bool = True


class VenueHoursInput(BaseModel):
    days_label: str = Field(min_length=1, max_length=80)
    open_time: str = Field(pattern=r'^\d{2}:\d{2}$')
    close_time: str = Field(pattern=r'^\d{2}:\d{2}$')
    sort_order: int = 0


class VenueAdminInput(BaseModel):
    id: str = Field(pattern=r'^[a-z0-9_]{3,64}$')
    city_id: str
    short_name: str = Field(min_length=1, max_length=120)
    full_address: str = Field(min_length=1, max_length=300)
    phone: str = Field(min_length=3, max_length=40)
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    sort_order: int = 0
    is_active: bool = True
    default_cook_minutes: int = Field(default=15, ge=1, le=180)
    hours: list[VenueHoursInput] = Field(default_factory=list)


class CategoryAdminInput(BaseModel):
    id: str = Field(pattern=r'^[a-z0-9_]{3,64}$')
    title: str = Field(min_length=1, max_length=120)
    parent_id: str | None = None
    image_media_id: str | None = None
    sort_order: int = 0
    is_active: bool = True


class ProductSizeInput(BaseModel):
    id: str = Field(pattern=r'^[a-z0-9_]{1,64}$')
    label: str = Field(min_length=1, max_length=80)
    ml: int = Field(ge=1, le=5000)
    price_delta: float = Field(default=0, ge=0)
    sort_order: int = 0
    is_active: bool = True


class ProductNutritionInput(BaseModel):
    weight_g: float | None = Field(default=None, ge=0)
    proteins: float | None = Field(default=None, ge=0)
    fats: float | None = Field(default=None, ge=0)
    carbs: float | None = Field(default=None, ge=0)
    kcal: float | None = Field(default=None, ge=0)


class ProductCompositionInput(BaseModel):
    sizes: list[ProductSizeInput] = Field(default_factory=list)
    modifier_group_ids: list[str] = Field(default_factory=list)
    nutrition: ProductNutritionInput = Field(default_factory=ProductNutritionInput)


class ModifierGroupAdminInput(BaseModel):
    id: str = Field(pattern=r'^[a-z0-9_]{3,64}$')
    title: str = Field(min_length=1, max_length=120)
    required: bool = False
    sort_order: int = 0
    is_active: bool = True


class ModifierOptionAdminInput(BaseModel):
    id: str = Field(pattern=r'^[a-z0-9_]{1,64}$')
    title: str = Field(min_length=1, max_length=120)
    price_delta: float = Field(default=0, ge=0)
    is_default: bool = False
    sort_order: int = 0
    is_active: bool = True


class PaymentStartRequest(BaseModel):
    # Kept for a stable client contract. Redirect URI is server-configured so a
    # client cannot redirect a successful payment to an untrusted site.
    pass


class OrderStatusUpdate(BaseModel):
    status: str


class StaffCreateRequest(BaseModel):
    email: str
    password: str = Field(min_length=12, max_length=256)
    role: str
    venue_ids: list[str] = Field(default_factory=list)


class StaffUpdateRequest(BaseModel):
    role: str | None = None
    is_active: bool | None = None
    venue_ids: list[str] | None = None


def _b64(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b'=').decode()


def _b64decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + '=' * (-len(value) % 4))


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1)
    return f'scrypt${_b64(salt)}${_b64(digest)}'


def password_matches(password: str, encoded: str) -> bool:
    try:
        algorithm, salt_text, digest_text = encoded.split('$', 2)
        if algorithm != 'scrypt':
            return False
        actual = hashlib.scrypt(password.encode(), salt=_b64decode(salt_text), n=2**14, r=8, p=1)
        return hmac.compare_digest(actual, _b64decode(digest_text))
    except (ValueError, TypeError):
        return False


def issue_staff_token(staff: dict[str, Any]) -> str:
    if not STAFF_TOKEN_SECRET:
        raise HTTPException(status_code=503, detail='Staff authentication is not configured')
    payload = {
        'sub': staff['id'], 'role': staff['role'], 'exp': int(time.time()) + 8 * 60 * 60,
    }
    encoded = _b64(json.dumps(payload, separators=(',', ':')).encode())
    signature = _b64(hmac.new(STAFF_TOKEN_SECRET.encode(), encoded.encode(), hashlib.sha256).digest())
    return f'{encoded}.{signature}'


def current_staff(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    if not STAFF_TOKEN_SECRET:
        raise HTTPException(status_code=503, detail='Staff authentication is not configured')
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(status_code=401, detail='Staff authentication is required')
    token = authorization.removeprefix('Bearer ')
    try:
        encoded, received_signature = token.split('.', 1)
        expected_signature = _b64(hmac.new(STAFF_TOKEN_SECRET.encode(), encoded.encode(), hashlib.sha256).digest())
        payload = json.loads(_b64decode(encoded))
        if not hmac.compare_digest(received_signature, expected_signature) or payload['exp'] < time.time():
            raise ValueError
    except (ValueError, KeyError, json.JSONDecodeError):
        raise HTTPException(status_code=401, detail='Invalid or expired staff session')
    with db() as conn:
        staff = conn.execute(
            'SELECT id, email, role, is_active FROM staff_users WHERE id = %s', (payload['sub'],),
        ).fetchone()
    if not staff or not staff['is_active']:
        raise HTTPException(status_code=401, detail='Staff account is inactive')
    return staff


def staff_guard(*roles: str):
    def guard(authorization: str | None = Header(default=None)) -> dict[str, Any]:
        staff = current_staff(authorization)
        if staff['role'] not in roles:
            raise HTTPException(status_code=403, detail='Insufficient staff role')
        return staff
    return guard


def assert_staff_venue_access(conn: psycopg.Connection, staff: dict[str, Any], venue_id: str) -> None:
    """Ensure a non-admin can never read or change a different venue."""
    venue = conn.execute('SELECT id FROM venues WHERE id = %s AND is_active = TRUE', (venue_id,)).fetchone()
    if not venue:
        raise HTTPException(status_code=404, detail='Venue not found')
    if staff['role'] == 'admin':
        return
    access = conn.execute(
        'SELECT 1 FROM staff_venue_access WHERE staff_id = %s AND venue_id = %s',
        (staff['id'], venue_id),
    ).fetchone()
    if not access:
        raise HTTPException(status_code=403, detail='No access to this venue')


def _quote(conn: psycopg.Connection, payload: QuoteRequest) -> dict[str, Any]:
    venue = conn.execute('SELECT id FROM venues WHERE id = %s AND is_active = TRUE', (payload.venue_id,)).fetchone()
    if not venue:
        raise HTTPException(status_code=404, detail='Venue not found')

    lines: list[dict[str, Any]] = []
    subtotal = 0.0
    for requested in payload.items:
        product = conn.execute(
            '''
            SELECT p.id, p.title, COALESCE(vp.price, p.price) AS price
            FROM products p
            LEFT JOIN venue_product_overrides vp
              ON vp.product_id = p.id AND vp.venue_id = %s
            WHERE p.id = %s AND p.is_active = TRUE
              AND COALESCE(vp.is_available, TRUE) = TRUE
              AND NOT EXISTS (
                SELECT 1 FROM product_stop_list s
                WHERE s.venue_id = %s AND s.product_id = p.id AND s.is_stopped = TRUE
              )
            ''',
            (payload.venue_id, requested.product_id, payload.venue_id),
        ).fetchone()
        if not product:
            raise HTTPException(status_code=409, detail=f'Product unavailable: {requested.product_id}')

        size_delta = 0.0
        if requested.size_id:
            size = conn.execute(
                'SELECT price_delta FROM product_sizes WHERE product_id = %s AND id = %s AND is_active = TRUE',
                (product['id'], requested.size_id),
            ).fetchone()
            if not size:
                raise HTTPException(status_code=422, detail='Unknown size')
            size_delta = money(size['price_delta'])

        groups = conn.execute(
            '''SELECT g.id, g.title, g.required
               FROM modifier_groups g
               JOIN product_modifier_groups pg ON pg.group_id = g.id
               WHERE pg.product_id = %s AND g.is_active = TRUE''',
            (product['id'],),
        ).fetchall()
        selected: list[dict[str, Any]] = []
        selected_groups = {m.group_id for m in requested.modifiers}
        if len(selected_groups) != len(requested.modifiers):
            raise HTTPException(status_code=422, detail='Only one option is allowed per modifier group')
        for group in groups:
            if group['required'] and group['id'] not in selected_groups:
                raise HTTPException(status_code=422, detail=f"Required modifier: {group['title']}")
        for modifier in requested.modifiers:
            group = next((g for g in groups if g['id'] == modifier.group_id), None)
            if not group:
                raise HTTPException(status_code=422, detail='Modifier does not belong to product')
            option = conn.execute(
                '''SELECT o.id, o.title, COALESCE(vo.price_delta, o.price_delta) AS price_delta
                   FROM modifier_options o
                   LEFT JOIN venue_modifier_option_overrides vo
                     ON vo.group_id = o.group_id AND vo.option_id = o.id AND vo.venue_id = %s
                   WHERE o.group_id = %s AND o.id = %s AND o.is_active = TRUE AND COALESCE(vo.is_available, TRUE) = TRUE''',
                (payload.venue_id, modifier.group_id, modifier.option_id),
            ).fetchone()
            if not option:
                raise HTTPException(status_code=422, detail='Unknown modifier option')
            selected.append({
                'groupId': group['id'], 'groupTitle': group['title'],
                'optionId': option['id'], 'optionTitle': option['title'],
                'priceDelta': money(option['price_delta']),
            })
        unit_price = money(product['price']) + size_delta + sum(x['priceDelta'] for x in selected)
        line_total = unit_price * requested.qty
        subtotal += line_total
        lines.append({
            'productId': product['id'], 'title': product['title'], 'qty': requested.qty,
            'unitPrice': unit_price, 'lineTotal': line_total, 'modifiers': selected,
        })

    discount = 0.0
    if payload.promo_code:
        promo = conn.execute(
            'SELECT discount_percent, discount_amount FROM promo_codes WHERE code = %s AND is_active = TRUE',
            (payload.promo_code.strip().upper(),),
        ).fetchone()
        if not promo:
            raise HTTPException(status_code=422, detail='Promo code is invalid')
        discount = money(promo['discount_amount']) or subtotal * money(promo['discount_percent']) / 100
        discount = min(discount, subtotal)
    return {'items': lines, 'subtotal': round(subtotal, 2), 'discount': round(discount, 2), 'total': round(subtotal - discount, 2)}


def _apply_loyalty(
    conn: psycopg.Connection,
    quote: dict[str, Any],
    requested_points: int,
    user_id: str,
    *,
    lock_user: bool = False,
) -> dict[str, Any]:
    suffix = ' FOR UPDATE' if lock_user else ''
    user = conn.execute(
        f'SELECT id, bonus_balance FROM users WHERE id = %s{suffix}',
        (user_id,),
    ).fetchone()
    if not user:
        raise HTTPException(status_code=404, detail='User not found')

    balance = int(user['bonus_balance'])
    if Decimal(str(quote['total'])) < MINIMUM_CASH_PAYMENT:
        raise HTTPException(
            status_code=422,
            detail='Сумма заказа после скидок должна быть не меньше 1 ₽',
        )
    order_limit = maximum_bonus_points(quote['total'])
    available = min(balance, order_limit)
    if requested_points > balance:
        raise HTTPException(status_code=409, detail='Недостаточно бонусов на балансе')
    if requested_points > order_limit:
        raise HTTPException(
            status_code=422,
            detail='После списания бонусов к оплате должен остаться минимум 1 ₽',
        )

    payment_total = round(money(quote['total']) - requested_points, 2)
    return {
        **quote,
        'bonusBalance': balance,
        'maxBonusPoints': available,
        'bonusSpent': requested_points,
        'paymentTotal': payment_total,
        'bonusEarnedPreview': earned_bonus_points(payment_total),
    }


def _award_order_bonuses(conn: psycopg.Connection, order_id: str) -> int:
    """Award once after issue; the ledger and order snapshot make it idempotent."""
    order = conn.execute(
        '''SELECT id, user_id, status, payment_total, bonus_earned
           FROM orders WHERE id = %s FOR UPDATE''',
        (order_id,),
    ).fetchone()
    if not order or order['status'] != 'issued' or not order['user_id']:
        return 0
    if int(order['bonus_earned'] or 0) > 0:
        return int(order['bonus_earned'])
    existing = conn.execute(
        "SELECT 1 FROM bonus_transactions WHERE order_id = %s AND kind = 'earn'",
        (order_id,),
    ).fetchone()
    if existing:
        return 0

    points = earned_bonus_points(order['payment_total'])
    if points <= 0:
        return 0
    user = conn.execute(
        'SELECT bonus_balance FROM users WHERE id = %s FOR UPDATE',
        (order['user_id'],),
    ).fetchone()
    if not user:
        return 0
    balance_after = int(user['bonus_balance']) + points
    conn.execute(
        'UPDATE users SET bonus_balance = %s WHERE id = %s',
        (balance_after, order['user_id']),
    )
    conn.execute(
        'UPDATE orders SET bonus_earned = %s WHERE id = %s',
        (points, order_id),
    )
    conn.execute(
        '''INSERT INTO bonus_transactions
           (id, user_id, order_id, kind, points, balance_after, description)
           VALUES (%s, %s, %s, 'earn', %s, %s, %s)''',
        (
            str(uuid.uuid4()), order['user_id'], order_id, points, balance_after,
            '5% за выданный заказ',
        ),
    )
    return points


def _refund_order_bonuses(conn: psycopg.Connection, order_id: str) -> int:
    order = conn.execute(
        '''SELECT id, user_id, bonus_spent FROM orders
           WHERE id = %s FOR UPDATE''',
        (order_id,),
    ).fetchone()
    if not order or not order['user_id'] or int(order['bonus_spent'] or 0) <= 0:
        return 0
    existing = conn.execute(
        "SELECT 1 FROM bonus_transactions WHERE order_id = %s AND kind = 'refund'",
        (order_id,),
    ).fetchone()
    if existing:
        return 0

    points = int(order['bonus_spent'])
    user = conn.execute(
        'SELECT bonus_balance FROM users WHERE id = %s FOR UPDATE',
        (order['user_id'],),
    ).fetchone()
    if not user:
        return 0
    balance_after = int(user['bonus_balance']) + points
    conn.execute(
        'UPDATE users SET bonus_balance = %s WHERE id = %s',
        (balance_after, order['user_id']),
    )
    conn.execute(
        '''INSERT INTO bonus_transactions
           (id, user_id, order_id, kind, points, balance_after, description)
           VALUES (%s, %s, %s, 'refund', %s, %s, %s)''',
        (
            str(uuid.uuid4()), order['user_id'], order_id, points, balance_after,
            'Возврат за отменённую оплату',
        ),
    )
    return points


def _cancel_failed_payment(order_id: str) -> None:
    with db() as conn:
        order = conn.execute(
            'SELECT status FROM orders WHERE id = %s FOR UPDATE',
            (order_id,),
        ).fetchone()
        if not order or order['status'] != 'pending_payment':
            return
        _refund_order_bonuses(conn, order_id)
        conn.execute(
            "UPDATE orders SET status = 'cancelled', updated_at = NOW() WHERE id = %s",
            (order_id,),
        )
        conn.execute(
            '''INSERT INTO order_status_events
               (id, order_id, from_status, to_status, actor_type)
               VALUES (%s, %s, 'pending_payment', 'cancelled', 'payment_provider')''',
            (str(uuid.uuid4()), order_id),
        )


def yookassa_settings() -> tuple[str, str, str]:
    shop_id = os.environ.get('YOOKASSA_SHOP_ID', '')
    secret_key = os.environ.get('YOOKASSA_SECRET_KEY', '')
    return_url = os.environ.get('YOOKASSA_RETURN_URL', '')
    if not shop_id or not secret_key or not return_url:
        raise HTTPException(status_code=503, detail='YooKassa test credentials are not configured')
    return shop_id, secret_key, return_url


async def fetch_yookassa_payment(external_id: str) -> dict[str, Any]:
    shop_id, secret_key, _ = yookassa_settings()
    import httpx
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f'https://api.yookassa.ru/v3/payments/{external_id}', auth=(shop_id, secret_key),
        )
    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail='Could not verify YooKassa payment')
    return response.json()


def persist_yookassa_state(remote: dict[str, Any]) -> str:
    external_id = remote.get('id')
    metadata = remote.get('metadata') or {}
    order_id = metadata.get('order_id')
    status = remote.get('status')
    if not external_id or not order_id or not status:
        raise HTTPException(status_code=422, detail='Invalid YooKassa payment payload')
    with db() as conn:
        payment = conn.execute(
            'SELECT id, order_id, status FROM payments WHERE external_id = %s', (external_id,),
        ).fetchone()
        if not payment or payment['order_id'] != order_id:
            raise HTTPException(status_code=404, detail='Payment is not linked to this order')
        conn.execute(
            '''UPDATE payments SET status = %s, raw_payload = %s, updated_at = NOW()
               WHERE id = %s''',
            (status, json.dumps(remote), payment['id']),
        )
        if status == 'succeeded':
            order = conn.execute('SELECT venue_id, status FROM orders WHERE id = %s', (order_id,)).fetchone()
            if not order:
                raise HTTPException(status_code=404, detail='Order not found')
            minutes = conn.execute(
                'SELECT default_cook_minutes FROM venue_settings WHERE venue_id = %s', (order['venue_id'],),
            ).fetchone()
            cook_minutes = minutes['default_cook_minutes'] if minutes else 15
            if order['status'] == 'pending_payment':
                conn.execute(
                    '''UPDATE orders SET status = 'confirmed', paid_at = NOW(), updated_at = NOW(),
                       ready_estimate_at = NOW() + (%s * INTERVAL '1 minute') WHERE id = %s''',
                    (cook_minutes, order_id),
                )
                conn.execute(
                    '''INSERT INTO order_status_events (id, order_id, from_status, to_status, actor_type)
                       VALUES (%s, %s, 'pending_payment', 'confirmed', 'payment_provider')''',
                    (str(uuid.uuid4()), order_id),
                )
        elif status == 'canceled':
            order = conn.execute(
                'SELECT status FROM orders WHERE id = %s FOR UPDATE',
                (order_id,),
            ).fetchone()
            if order and order['status'] == 'pending_payment':
                _refund_order_bonuses(conn, order_id)
                conn.execute(
                    "UPDATE orders SET status = 'cancelled', updated_at = NOW() WHERE id = %s",
                    (order_id,),
                )
                conn.execute(
                    '''INSERT INTO order_status_events
                       (id, order_id, from_status, to_status, actor_type)
                       VALUES (%s, %s, 'pending_payment', 'cancelled', 'payment_provider')''',
                    (str(uuid.uuid4()), order_id),
                )
    return status


@app.get("/health")
def health() -> dict[str, str]:
    with db() as conn:
        conn.execute("SELECT 1")
    return {"status": "ok"}


@app.get("/cities")
def cities() -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute("SELECT id, name FROM cities WHERE is_active = TRUE ORDER BY sort_order, name").fetchall()
    return [{"id": r["id"], "name": r["name"]} for r in rows]


@app.get("/venues")
def venues(city_id: str | None = Query(default=None)) -> list[dict[str, Any]]:
    with db() as conn:
        if city_id:
            venue_rows = conn.execute(
                """
                SELECT id, city_id, short_name, full_address, phone, lat, lng
                FROM venues WHERE city_id = %s AND is_active = TRUE ORDER BY sort_order, short_name
                """,
                (city_id,),
            ).fetchall()
        else:
            venue_rows = conn.execute(
                """
                SELECT id, city_id, short_name, full_address, phone, lat, lng
                FROM venues WHERE is_active = TRUE ORDER BY city_id, sort_order, short_name
                """
            ).fetchall()

        result: list[dict[str, Any]] = []
        for v in venue_rows:
            hours = conn.execute(
                """
                SELECT days_label, open_time, close_time
                FROM venue_hours WHERE venue_id = %s ORDER BY sort_order, id
                """,
                (v["id"],),
            ).fetchall()
            result.append(
                {
                    "id": v["id"],
                    "cityId": v["city_id"],
                    "shortName": v["short_name"],
                    "fullAddress": v["full_address"],
                    "phone": v["phone"],
                    "lat": v["lat"],
                    "lng": v["lng"],
                    "hours": [
                        {
                            "daysLabel": h["days_label"],
                            "open": h["open_time"],
                            "close": h["close_time"],
                        }
                        for h in hours
                    ],
                }
            )
    return result


@app.get("/categories")
def categories() -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute(
            """
            SELECT c.id, c.title, c.parent_id, m.object_key
            FROM categories c
            LEFT JOIN media_assets m ON m.id = c.image_media_id
            WHERE c.is_active = TRUE
            ORDER BY c.sort_order, c.title
            """
        ).fetchall()
    return [
        {
            "id": r["id"],
            "title": r["title"],
            "parentId": r["parent_id"],
            "imageUrl": media_url(r["object_key"]),
        }
        for r in rows
    ]


def _load_product(conn: psycopg.Connection, product_id: str, venue_id: str | None = None) -> dict[str, Any] | None:
    p = conn.execute(
        """
        SELECT p.id, p.category_id, p.title, p.description, COALESCE(vp.price, p.price) AS price,
               p.image_media_id, p.weight_label, p.featured, p.weight_g, p.proteins, p.fats, p.carbs, p.kcal
        FROM products p
        LEFT JOIN venue_product_overrides vp ON vp.product_id = p.id AND vp.venue_id = %s
        WHERE p.id = %s
        """,
        (venue_id, product_id),
    ).fetchone()
    if not p:
        return None

    media = None
    if p['image_media_id']:
        media = conn.execute(
            'SELECT object_key FROM media_assets WHERE id = %s',
            (p['image_media_id'],),
        ).fetchone()

    sizes = conn.execute(
        """
        SELECT id, label, ml, price_delta
        FROM product_sizes WHERE product_id = %s AND is_active = TRUE ORDER BY sort_order, ml
        """,
        (product_id,),
    ).fetchall()

    group_ids = [
        r["group_id"]
        for r in conn.execute(
            """
            SELECT group_id FROM product_modifier_groups
            WHERE product_id = %s
            """,
            (product_id,),
        ).fetchall()
    ]

    modifier_groups: list[dict[str, Any]] = []
    for gid in group_ids:
        g = conn.execute(
            "SELECT id, title, required FROM modifier_groups WHERE id = %s AND is_active = TRUE",
            (gid,),
        ).fetchone()
        if not g:
            continue
        opts = conn.execute(
            """
            SELECT o.id, o.title, COALESCE(vo.price_delta, o.price_delta) AS price_delta, o.is_default
            FROM modifier_options o
            LEFT JOIN venue_modifier_option_overrides vo
              ON vo.group_id = o.group_id AND vo.option_id = o.id AND vo.venue_id = %s
            WHERE o.group_id = %s AND o.is_active = TRUE AND COALESCE(vo.is_available, TRUE) = TRUE
            ORDER BY is_default DESC, o.sort_order, title
            """,
            (venue_id, gid),
        ).fetchall()
        modifier_groups.append(
            {
                "id": g["id"],
                "title": g["title"],
                "required": g["required"],
                "options": [
                    {
                        "id": o["id"],
                        "title": o["title"],
                        "priceDelta": money(o["price_delta"]),
                        "isDefault": o["is_default"],
                    }
                    for o in opts
                ],
            }
        )

    nutrition = None
    if p["kcal"] is not None:
        nutrition = {
            "weightG": money(p["weight_g"] or 0),
            "proteins": money(p["proteins"] or 0),
            "fats": money(p["fats"] or 0),
            "carbs": money(p["carbs"] or 0),
            "kcal": money(p["kcal"] or 0),
        }

    return {
        "id": p["id"],
        "categoryId": p["category_id"],
        "title": p["title"],
        "description": p["description"],
        "price": money(p["price"]),
        "imageUrl": media_url(media['object_key']) if media else None,
        "weightLabel": p["weight_label"],
        "featured": p["featured"],
        "nutrition": nutrition,
        "sizes": [
            {
                "id": s["id"],
                "label": s["label"],
                "ml": s["ml"],
                "priceDelta": money(s["price_delta"]),
            }
            for s in sizes
        ],
        "modifierGroups": modifier_groups,
    }


@app.get("/products")
def products(
    category_id: str | None = Query(default=None),
    featured: bool | None = Query(default=None),
    q: str | None = Query(default=None),
) -> list[dict[str, Any]]:
    clauses: list[str] = []
    params: list[Any] = []
    if category_id:
        clauses.append("category_id = %s")
        params.append(category_id)
    if featured is True:
        clauses.append("featured = TRUE")
    if q:
        clauses.append("(title ILIKE %s OR description ILIKE %s)")
        like = f"%{q}%"
        params.extend([like, like])

    clauses.append('is_active = TRUE')
    where = f"WHERE {' AND '.join(clauses)}"
    with db() as conn:
        ids = [
            r["id"]
            for r in conn.execute(
                f"SELECT id FROM products {where} ORDER BY featured DESC, title",
                params,
            ).fetchall()
        ]
        return [_load_product(conn, pid) for pid in ids]  # type: ignore[misc]


@app.get('/menu')
def menu(venue_id: str = Query(...)) -> list[dict[str, Any]]:
    """Current venue-aware catalog for the mobile app."""
    with db() as conn:
        venue = conn.execute('SELECT id FROM venues WHERE id = %s', (venue_id,)).fetchone()
        if not venue:
            raise HTTPException(status_code=404, detail='Venue not found')
        rows = conn.execute(
            '''
            SELECT p.id
            FROM products p
            LEFT JOIN venue_product_overrides vp
              ON vp.product_id = p.id AND vp.venue_id = %s
            WHERE p.is_active = TRUE
              AND COALESCE(vp.is_available, TRUE) = TRUE
              AND NOT EXISTS (
                SELECT 1 FROM product_stop_list s
                WHERE s.product_id = p.id AND s.venue_id = %s AND s.is_stopped = TRUE
              )
            ORDER BY p.sort_order, p.featured DESC, p.title
            ''',
            (venue_id, venue_id),
        ).fetchall()
        return [_load_product(conn, row['id'], venue_id) for row in rows]  # type: ignore[misc]


@app.post('/orders/quote')
def quote_order(payload: QuoteRequest) -> dict[str, Any]:
    with db() as conn:
        return _apply_loyalty(conn, _quote(conn, payload), payload.bonus_points, 'u_demo')


@app.post('/admin/login')
def staff_login(payload: StaffLoginRequest) -> dict[str, Any]:
    with db() as conn:
        staff = conn.execute(
            '''SELECT id, email, password_hash, role, is_active
               FROM staff_users WHERE LOWER(email) = LOWER(%s)''',
            (payload.email.strip(),),
        ).fetchone()
    if not staff or not staff['is_active'] or not password_matches(payload.password, staff['password_hash']):
        raise HTTPException(status_code=401, detail='Invalid email or password')
    return {
        'accessToken': issue_staff_token(staff),
        'staff': {'id': staff['id'], 'email': staff['email'], 'role': staff['role']},
    }


@app.get('/admin/session')
def admin_session(staff: dict[str, Any] = Depends(current_staff)) -> dict[str, Any]:
    return {'id': staff['id'], 'email': staff['email'], 'role': staff['role']}


@app.get('/admin/products')
def admin_products(staff: dict[str, Any] = Depends(staff_guard('admin', 'manager', 'barista'))) -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute(
            '''SELECT p.id, p.category_id, p.title, p.description, p.price, p.image_media_id, p.is_active,
                      p.sort_order, p.weight_label, p.featured, m.object_key
               FROM products p LEFT JOIN media_assets m ON m.id = p.image_media_id
               ORDER BY p.sort_order, p.title''',
        ).fetchall()
    return [{
        'id': r['id'], 'categoryId': r['category_id'], 'title': r['title'], 'description': r['description'],
        'price': money(r['price']), 'imageMediaId': r['image_media_id'],
        'imageUrl': media_url(r['object_key']), 'isActive': r['is_active'],
        'sortOrder': r['sort_order'], 'weightLabel': r['weight_label'], 'featured': r['featured'],
    } for r in rows]


@app.post('/admin/products', status_code=201)
def create_admin_product(payload: ProductAdminCreate, staff: dict[str, Any] = Depends(staff_guard('admin'))) -> dict[str, Any]:
    with db() as conn:
        category = conn.execute('SELECT 1 FROM categories WHERE id = %s AND is_active = TRUE', (payload.category_id,)).fetchone()
        if not category:
            raise HTTPException(status_code=422, detail='Unknown active category')
        if payload.image_media_id and not conn.execute('SELECT 1 FROM media_assets WHERE id = %s', (payload.image_media_id,)).fetchone():
            raise HTTPException(status_code=422, detail='Unknown media asset')
        exists = conn.execute('SELECT 1 FROM products WHERE id = %s', (payload.id,)).fetchone()
        if exists:
            raise HTTPException(status_code=409, detail='Product id already exists')
        conn.execute('''INSERT INTO products (id, category_id, title, description, price, weight_label, featured, image_media_id, is_active, sort_order)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,TRUE,%s)''', (payload.id, payload.category_id, payload.title, payload.description, payload.price, payload.weight_label, payload.featured, payload.image_media_id, payload.sort_order))
        return _load_product(conn, payload.id)  # type: ignore[return-value]


@app.patch('/admin/products/{product_id}')
def update_admin_product(
    product_id: str,
    payload: ProductAdminUpdate,
    staff: dict[str, Any] = Depends(staff_guard('admin')),
) -> dict[str, Any]:
    values = payload.model_dump(exclude_unset=True)
    if not values:
        raise HTTPException(status_code=422, detail='No fields to update')
    with db() as conn:
        if 'image_media_id' in values and values['image_media_id']:
            media = conn.execute('SELECT id FROM media_assets WHERE id = %s', (values['image_media_id'],)).fetchone()
            if not media:
                raise HTTPException(status_code=422, detail='Unknown media asset')
        columns = {
            'category_id': 'category_id', 'title': 'title', 'description': 'description', 'price': 'price',
            'image_media_id': 'image_media_id', 'weight_label': 'weight_label', 'featured': 'featured',
            'is_active': 'is_active', 'sort_order': 'sort_order',
        }
        assignments = [f"{columns[key]} = %s" for key in values]
        result = conn.execute(
            f"UPDATE products SET {', '.join(assignments)} WHERE id = %s RETURNING id",
            [*values.values(), product_id],
        ).fetchone()
        if not result:
            raise HTTPException(status_code=404, detail='Product not found')
        updated = _load_product(conn, product_id)
    return updated  # type: ignore[return-value]


@app.get('/admin/promo-slides')
def admin_promo_slides(staff: dict[str, Any] = Depends(staff_guard('admin', 'manager'))) -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute(
            '''SELECT p.id, p.title, p.body, p.image_media_id, p.is_active, p.sort_order, m.object_key
               FROM promo_slides p LEFT JOIN media_assets m ON m.id = p.image_media_id
               ORDER BY p.sort_order''',
        ).fetchall()
    return [{
        'id': r['id'], 'title': r['title'], 'body': r['body'], 'imageMediaId': r['image_media_id'],
        'imageUrl': media_url(r['object_key']), 'isActive': r['is_active'], 'sortOrder': r['sort_order'],
    } for r in rows]


@app.post('/admin/promo-slides', status_code=201)
def create_admin_promo(
    payload: PromoAdminCreate,
    staff: dict[str, Any] = Depends(staff_guard('admin')),
) -> dict[str, Any]:
    with db() as conn:
        if payload.image_media_id and not conn.execute('SELECT 1 FROM media_assets WHERE id = %s', (payload.image_media_id,)).fetchone():
            raise HTTPException(status_code=422, detail='Unknown media asset')
        if conn.execute('SELECT 1 FROM promo_slides WHERE id = %s', (payload.id,)).fetchone():
            raise HTTPException(status_code=409, detail='Promo slide id already exists')
        conn.execute('''INSERT INTO promo_slides (id,title,body,cta_url,image_media_id,sort_order,is_active)
                        VALUES (%s,%s,%s,%s,%s,%s,%s)''', (payload.id, payload.title, payload.body, payload.cta_url, payload.image_media_id, payload.sort_order, payload.is_active))
    return {'id': payload.id, 'status': 'created'}


@app.patch('/admin/promo-slides/{slide_id}')
def update_admin_promo(
    slide_id: str,
    payload: PromoAdminUpdate,
    staff: dict[str, Any] = Depends(staff_guard('admin')),
) -> dict[str, Any]:
    values = payload.model_dump(exclude_unset=True)
    if not values:
        raise HTTPException(status_code=422, detail='No fields to update')
    with db() as conn:
        if 'image_media_id' in values and values['image_media_id']:
            media = conn.execute('SELECT id FROM media_assets WHERE id = %s', (values['image_media_id'],)).fetchone()
            if not media:
                raise HTTPException(status_code=422, detail='Unknown media asset')
        columns = {
            'title': 'title', 'body': 'body', 'image_media_id': 'image_media_id',
            'is_active': 'is_active', 'sort_order': 'sort_order',
        }
        assignments = [f"{columns[key]} = %s" for key in values]
        row = conn.execute(
            f"UPDATE promo_slides SET {', '.join(assignments)} WHERE id = %s RETURNING id",
            [*values.values(), slide_id],
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail='Promo slide not found')
    return {'id': slide_id, 'status': 'updated'}


@app.put('/admin/venues/{venue_id}/stop-list/{product_id}')
def update_stop_list(
    venue_id: str,
    product_id: str,
    payload: StopListUpdate,
    staff: dict[str, Any] = Depends(staff_guard('admin', 'manager', 'barista')),
) -> dict[str, Any]:
    with db() as conn:
        assert_staff_venue_access(conn, staff, venue_id)
        conn.execute(
            '''INSERT INTO product_stop_list (venue_id, product_id, is_stopped, updated_at)
               VALUES (%s, %s, %s, NOW())
               ON CONFLICT (venue_id, product_id) DO UPDATE SET
                 is_stopped = EXCLUDED.is_stopped, updated_at = NOW()''',
            (venue_id, product_id, payload.is_stopped),
        )
    return {'venueId': venue_id, 'productId': product_id, 'isStopped': payload.is_stopped}


@app.get('/admin/dashboard')
def admin_dashboard(
    days: int = Query(default=7, ge=1, le=90),
    venue_id: str | None = None,
    staff: dict[str, Any] = Depends(staff_guard('admin', 'manager')),
) -> dict[str, Any]:
    with db() as conn:
        if staff['role'] != 'admin':
            allowed = [r['venue_id'] for r in conn.execute('SELECT venue_id FROM staff_venue_access WHERE staff_id = %s', (staff['id'],)).fetchall()]
            if venue_id and venue_id not in allowed:
                raise HTTPException(status_code=403, detail='No access to this venue')
        else:
            allowed = []
        filters = ["created_at >= NOW() - (%s * INTERVAL '1 day')"]
        params: list[Any] = [days]
        if venue_id:
            filters.append('venue_id = %s'); params.append(venue_id)
        elif allowed:
            filters.append('venue_id = ANY(%s)'); params.append(allowed)
        where = ' AND '.join(filters)
        totals = conn.execute(f'''SELECT COUNT(*) FILTER (WHERE status <> 'cancelled') AS orders, COALESCE(SUM(payment_total) FILTER (WHERE status <> 'cancelled'),0) AS revenue,
            COALESCE(AVG(payment_total) FILTER (WHERE status <> 'cancelled'),0) AS average_check,
            COUNT(*) FILTER (WHERE status IN ('pending_payment','confirmed','preparing','ready')) AS active_orders
            FROM orders WHERE {where}''', params).fetchone()
        venue_filter = 'WHERE v.id = %s' if venue_id else ('WHERE v.id = ANY(%s)' if allowed else '')
        venue_params = [days, venue_id] if venue_id else ([days, allowed] if allowed else [days])
        by_venue = conn.execute(f'''SELECT v.id, v.short_name, COUNT(o.id) FILTER (WHERE o.status <> 'cancelled') AS orders,
            COALESCE(SUM(o.payment_total) FILTER (WHERE o.status <> 'cancelled'),0) AS revenue
            FROM venues v LEFT JOIN orders o ON o.venue_id=v.id AND o.created_at >= NOW()-(%s*INTERVAL '1 day')
            {venue_filter} GROUP BY v.id, v.short_name ORDER BY revenue DESC''', venue_params).fetchall()
        daily = conn.execute(f'''SELECT date_trunc('day', created_at)::date AS day,
                    COUNT(*) FILTER (WHERE status <> 'cancelled') AS orders,
                    COALESCE(SUM(payment_total) FILTER (WHERE status <> 'cancelled'),0) AS revenue
                FROM orders WHERE {where} GROUP BY 1 ORDER BY 1''', params).fetchall()
    return {'days': days, 'orders': totals['orders'], 'revenue': money(totals['revenue']), 'averageCheck': money(totals['average_check']), 'activeOrders': totals['active_orders'], 'byVenue': [{'id':r['id'],'title':r['short_name'],'orders':r['orders'],'revenue':money(r['revenue'])} for r in by_venue], 'daily': [{'day': r['day'].isoformat(), 'orders': r['orders'], 'revenue': money(r['revenue'])} for r in daily]}


@app.put('/admin/venues/{venue_id}/products/{product_id}/override')
def set_venue_product_override(venue_id: str, product_id: str, payload: VenueProductOverrideInput, staff: dict[str, Any] = Depends(staff_guard('admin', 'manager'))) -> dict[str, Any]:
    with db() as conn:
        assert_staff_venue_access(conn, staff, venue_id)
        if not conn.execute('SELECT 1 FROM products WHERE id = %s', (product_id,)).fetchone():
            raise HTTPException(status_code=404, detail='Product not found')
        conn.execute('''INSERT INTO venue_product_overrides (venue_id,product_id,price,is_available) VALUES (%s,%s,%s,%s)
          ON CONFLICT (venue_id,product_id) DO UPDATE SET price=EXCLUDED.price,is_available=EXCLUDED.is_available,updated_at=NOW()''', (venue_id, product_id, payload.price, payload.is_available))
    return {'venueId':venue_id,'productId':product_id,'price':payload.price,'isAvailable':payload.is_available}


@app.put('/admin/venues/{venue_id}/modifier-options/{group_id}/{option_id}/override')
def set_venue_modifier_override(venue_id: str, group_id: str, option_id: str, payload: VenueModifierOverrideInput, staff: dict[str, Any] = Depends(staff_guard('admin', 'manager'))) -> dict[str, Any]:
    with db() as conn:
        assert_staff_venue_access(conn, staff, venue_id)
        if not conn.execute('SELECT 1 FROM modifier_options WHERE group_id = %s AND id = %s', (group_id, option_id)).fetchone():
            raise HTTPException(status_code=404, detail='Modifier option not found')
        conn.execute('''INSERT INTO venue_modifier_option_overrides (venue_id,group_id,option_id,is_available,price_delta) VALUES (%s,%s,%s,%s,%s)
          ON CONFLICT (venue_id,group_id,option_id) DO UPDATE SET is_available=EXCLUDED.is_available,price_delta=EXCLUDED.price_delta,updated_at=NOW()''', (venue_id,group_id,option_id,payload.is_available,payload.price_delta))
    return {'venueId':venue_id,'groupId':group_id,'optionId':option_id,'isAvailable':payload.is_available,'priceDelta':payload.price_delta}


@app.delete('/admin/venues/{venue_id}/products/{product_id}/override')
def reset_venue_product_override(venue_id: str, product_id: str, staff: dict[str, Any] = Depends(staff_guard('admin', 'manager'))) -> dict[str, Any]:
    with db() as conn:
        assert_staff_venue_access(conn, staff, venue_id)
        conn.execute('DELETE FROM venue_product_overrides WHERE venue_id = %s AND product_id = %s', (venue_id, product_id))
    return {'venueId': venue_id, 'productId': product_id, 'reset': True}


@app.delete('/admin/venues/{venue_id}/modifier-options/{group_id}/{option_id}/override')
def reset_venue_modifier_override(venue_id: str, group_id: str, option_id: str, staff: dict[str, Any] = Depends(staff_guard('admin', 'manager'))) -> dict[str, Any]:
    with db() as conn:
        assert_staff_venue_access(conn, staff, venue_id)
        conn.execute('''DELETE FROM venue_modifier_option_overrides
                        WHERE venue_id = %s AND group_id = %s AND option_id = %s''', (venue_id, group_id, option_id))
    return {'venueId': venue_id, 'groupId': group_id, 'optionId': option_id, 'reset': True}


@app.get('/admin/venues')
def admin_venues(staff: dict[str, Any] = Depends(staff_guard('admin', 'manager', 'barista'))) -> list[dict[str, Any]]:
    with db() as conn:
        where = ''
        params: list[Any] = []
        if staff['role'] != 'admin':
            where = 'JOIN staff_venue_access a ON a.venue_id = v.id AND a.staff_id = %s'
            params.append(staff['id'])
        rows = conn.execute(f'''SELECT v.id, v.city_id, c.name AS city_name, v.short_name, v.full_address,
                    v.phone, v.lat, v.lng, v.is_active, v.sort_order,
                    COALESCE(s.default_cook_minutes, 15) AS default_cook_minutes
                FROM venues v {where}
                JOIN cities c ON c.id = v.city_id
                LEFT JOIN venue_settings s ON s.venue_id = v.id
                ORDER BY c.sort_order, c.name, v.sort_order, v.short_name''', params).fetchall()
        result = []
        for row in rows:
            hours = conn.execute('''SELECT days_label, open_time, close_time, sort_order
                                    FROM venue_hours WHERE venue_id = %s ORDER BY sort_order, id''', (row['id'],)).fetchall()
            result.append({
                'id': row['id'], 'cityId': row['city_id'], 'cityName': row['city_name'],
                'shortName': row['short_name'], 'fullAddress': row['full_address'], 'phone': row['phone'],
                'lat': row['lat'], 'lng': row['lng'], 'isActive': row['is_active'], 'sortOrder': row['sort_order'],
                'defaultCookMinutes': row['default_cook_minutes'],
                'hours': [{'daysLabel': h['days_label'], 'open': h['open_time'], 'close': h['close_time'], 'sortOrder': h['sort_order']} for h in hours],
            })
    return result


@app.get('/admin/venues/{venue_id}/menu')
def admin_venue_menu(venue_id: str, staff: dict[str, Any] = Depends(staff_guard('admin', 'manager', 'barista'))) -> dict[str, Any]:
    with db() as conn:
        assert_staff_venue_access(conn, staff, venue_id)
        products = conn.execute('''SELECT p.id, p.title, p.price AS base_price, p.is_active,
                    vp.price AS override_price, vp.is_available AS override_available,
                    COALESCE(sl.is_stopped, FALSE) AS is_stopped
                FROM products p
                LEFT JOIN venue_product_overrides vp ON vp.venue_id = %s AND vp.product_id = p.id
                LEFT JOIN product_stop_list sl ON sl.venue_id = %s AND sl.product_id = p.id
                ORDER BY p.sort_order, p.title''', (venue_id, venue_id)).fetchall()
        options = conn.execute('''SELECT g.id AS group_id, g.title AS group_title, o.id, o.title,
                    o.price_delta AS base_price_delta, vo.price_delta AS override_price_delta,
                    vo.is_available AS override_available
                FROM modifier_groups g JOIN modifier_options o ON o.group_id = g.id
                LEFT JOIN venue_modifier_option_overrides vo
                  ON vo.venue_id = %s AND vo.group_id = o.group_id AND vo.option_id = o.id
                WHERE g.is_active = TRUE AND o.is_active = TRUE
                ORDER BY g.sort_order, g.title, o.sort_order, o.title''', (venue_id,)).fetchall()
    return {
        'venueId': venue_id,
        'products': [{'id': p['id'], 'title': p['title'], 'basePrice': money(p['base_price']),
                      'overridePrice': money(p['override_price']) if p['override_price'] is not None else None,
                      'overrideAvailable': p['override_available'], 'isStopped': p['is_stopped'],
                      'isActive': p['is_active']} for p in products],
        'modifierOptions': [{'groupId': o['group_id'], 'groupTitle': o['group_title'], 'id': o['id'], 'title': o['title'],
                             'basePriceDelta': money(o['base_price_delta']),
                             'overridePriceDelta': money(o['override_price_delta']) if o['override_price_delta'] is not None else None,
                             'overrideAvailable': o['override_available']} for o in options],
    }


@app.get('/admin/orders')
def admin_orders(
    venue_id: str | None = None,
    status: str | None = None,
    staff: dict[str, Any] = Depends(staff_guard('admin', 'manager', 'barista')),
) -> list[dict[str, Any]]:
    with db() as conn:
        params: list[Any] = []
        clauses: list[str] = []
        if venue_id:
            assert_staff_venue_access(conn, staff, venue_id)
            clauses.append('o.venue_id = %s'); params.append(venue_id)
        elif staff['role'] != 'admin':
            clauses.append('o.venue_id IN (SELECT venue_id FROM staff_venue_access WHERE staff_id = %s)'); params.append(staff['id'])
        if status:
            clauses.append('o.status = %s'); params.append(status)
        where = f"WHERE {' AND '.join(clauses)}" if clauses else ''
        rows = conn.execute(f'''SELECT o.id, o.venue_id, v.short_name, o.status, o.total, o.created_at,
                    o.ready_estimate_at, o.comment, o.summary_line
                FROM orders o JOIN venues v ON v.id = o.venue_id {where}
                ORDER BY o.created_at DESC LIMIT 200''', params).fetchall()
        result = []
        for row in rows:
            items = conn.execute('''SELECT title_snapshot, qty, unit_price, line_total
                                    FROM order_items WHERE order_id = %s ORDER BY id''', (row['id'],)).fetchall()
            result.append({'id': row['id'], 'venueId': row['venue_id'], 'venueTitle': row['short_name'],
                           'status': row['status'], 'total': money(row['total']), 'createdAt': row['created_at'].isoformat(),
                           'readyEstimateAt': row['ready_estimate_at'].isoformat() if row['ready_estimate_at'] else None,
                           'comment': row['comment'], 'summaryLine': row['summary_line'],
                           'items': [{'title': i['title_snapshot'], 'qty': i['qty'], 'unitPrice': money(i['unit_price']), 'lineTotal': money(i['line_total'])} for i in items]})
    return result


@app.get('/admin/cities')
def admin_cities(staff: dict[str, Any] = Depends(staff_guard('admin'))) -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute('SELECT id, name, sort_order, is_active FROM cities ORDER BY sort_order, name').fetchall()
    return [{'id': r['id'], 'name': r['name'], 'sortOrder': r['sort_order'], 'isActive': r['is_active']} for r in rows]


@app.post('/admin/cities', status_code=201)
def create_admin_city(payload: CityAdminInput, staff: dict[str, Any] = Depends(staff_guard('admin'))) -> dict[str, Any]:
    with db() as conn:
        try:
            conn.execute('INSERT INTO cities (id, name, sort_order, is_active) VALUES (%s,%s,%s,%s)', (payload.id, payload.name, payload.sort_order, payload.is_active))
        except psycopg.errors.UniqueViolation as error:
            raise HTTPException(status_code=409, detail='City id already exists') from error
    return {'id': payload.id, 'status': 'created'}


@app.put('/admin/cities/{city_id}')
def update_admin_city(city_id: str, payload: CityAdminInput, staff: dict[str, Any] = Depends(staff_guard('admin'))) -> dict[str, Any]:
    if city_id != payload.id:
        raise HTTPException(status_code=422, detail='City id cannot be changed')
    with db() as conn:
        row = conn.execute('''UPDATE cities SET name=%s, sort_order=%s, is_active=%s WHERE id=%s RETURNING id''', (payload.name, payload.sort_order, payload.is_active, city_id)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail='City not found')
    return {'id': city_id, 'status': 'updated'}


def _write_venue_hours(conn: psycopg.Connection, venue_id: str, hours: list[VenueHoursInput]) -> None:
    conn.execute('DELETE FROM venue_hours WHERE venue_id = %s', (venue_id,))
    for hour in hours:
        conn.execute('''INSERT INTO venue_hours (venue_id, days_label, open_time, close_time, sort_order)
                        VALUES (%s,%s,%s,%s,%s)''', (venue_id, hour.days_label, hour.open_time, hour.close_time, hour.sort_order))


@app.post('/admin/venues', status_code=201)
def create_admin_venue(payload: VenueAdminInput, staff: dict[str, Any] = Depends(staff_guard('admin'))) -> dict[str, Any]:
    with db() as conn:
        if not conn.execute('SELECT 1 FROM cities WHERE id = %s AND is_active = TRUE', (payload.city_id,)).fetchone():
            raise HTTPException(status_code=422, detail='Unknown active city')
        if conn.execute('SELECT 1 FROM venues WHERE id = %s', (payload.id,)).fetchone():
            raise HTTPException(status_code=409, detail='Venue id already exists')
        conn.execute('''INSERT INTO venues (id, city_id, short_name, full_address, phone, lat, lng, sort_order, is_active)
                        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)''', (payload.id, payload.city_id, payload.short_name, payload.full_address, payload.phone, payload.lat, payload.lng, payload.sort_order, payload.is_active))
        conn.execute('''INSERT INTO venue_settings (venue_id, default_cook_minutes) VALUES (%s,%s)
                        ON CONFLICT (venue_id) DO UPDATE SET default_cook_minutes = EXCLUDED.default_cook_minutes''', (payload.id, payload.default_cook_minutes))
        _write_venue_hours(conn, payload.id, payload.hours)
    return {'id': payload.id, 'status': 'created'}


@app.put('/admin/venues/{venue_id}')
def update_admin_venue(venue_id: str, payload: VenueAdminInput, staff: dict[str, Any] = Depends(staff_guard('admin', 'manager'))) -> dict[str, Any]:
    if venue_id != payload.id:
        raise HTTPException(status_code=422, detail='Venue id cannot be changed')
    with db() as conn:
        assert_staff_venue_access(conn, staff, venue_id)
        if staff['role'] != 'admin' and (not payload.is_active or payload.city_id != conn.execute('SELECT city_id FROM venues WHERE id=%s', (venue_id,)).fetchone()['city_id']):
            raise HTTPException(status_code=403, detail='Managers cannot move or archive a venue')
        row = conn.execute('''UPDATE venues SET city_id=%s, short_name=%s, full_address=%s, phone=%s, lat=%s, lng=%s, sort_order=%s, is_active=%s
                              WHERE id=%s RETURNING id''', (payload.city_id, payload.short_name, payload.full_address, payload.phone, payload.lat, payload.lng, payload.sort_order, payload.is_active, venue_id)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail='Venue not found')
        conn.execute('''INSERT INTO venue_settings (venue_id, default_cook_minutes) VALUES (%s,%s)
                        ON CONFLICT (venue_id) DO UPDATE SET default_cook_minutes = EXCLUDED.default_cook_minutes''', (venue_id, payload.default_cook_minutes))
        _write_venue_hours(conn, venue_id, payload.hours)
    return {'id': venue_id, 'status': 'updated'}


@app.get('/admin/categories')
def admin_categories(staff: dict[str, Any] = Depends(staff_guard('admin', 'manager'))) -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute('''SELECT c.id, c.title, c.parent_id, c.image_media_id, c.sort_order, c.is_active, m.object_key
                               FROM categories c LEFT JOIN media_assets m ON m.id = c.image_media_id
                               ORDER BY c.sort_order, c.title''').fetchall()
    return [{'id': r['id'], 'title': r['title'], 'parentId': r['parent_id'], 'imageMediaId': r['image_media_id'],
             'imageUrl': media_url(r['object_key']), 'sortOrder': r['sort_order'], 'isActive': r['is_active']} for r in rows]


@app.post('/admin/categories', status_code=201)
def create_admin_category(payload: CategoryAdminInput, staff: dict[str, Any] = Depends(staff_guard('admin'))) -> dict[str, Any]:
    with db() as conn:
        if payload.parent_id and not conn.execute('SELECT 1 FROM categories WHERE id = %s', (payload.parent_id,)).fetchone():
            raise HTTPException(status_code=422, detail='Parent category not found')
        conn.execute('''INSERT INTO categories (id,title,parent_id,image_media_id,sort_order,is_active)
                        VALUES (%s,%s,%s,%s,%s,%s)''', (payload.id, payload.title, payload.parent_id, payload.image_media_id, payload.sort_order, payload.is_active))
    return {'id': payload.id, 'status': 'created'}


@app.put('/admin/categories/{category_id}')
def update_admin_category(category_id: str, payload: CategoryAdminInput, staff: dict[str, Any] = Depends(staff_guard('admin'))) -> dict[str, Any]:
    if category_id != payload.id:
        raise HTTPException(status_code=422, detail='Category id cannot be changed')
    with db() as conn:
        row = conn.execute('''UPDATE categories SET title=%s,parent_id=%s,image_media_id=%s,sort_order=%s,is_active=%s
                              WHERE id=%s RETURNING id''', (payload.title, payload.parent_id, payload.image_media_id, payload.sort_order, payload.is_active, category_id)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail='Category not found')
    return {'id': category_id, 'status': 'updated'}


@app.get('/admin/products/{product_id}/composition')
def get_product_composition(product_id: str, staff: dict[str, Any] = Depends(staff_guard('admin', 'manager'))) -> dict[str, Any]:
    with db() as conn:
        product = conn.execute('SELECT id, weight_g, proteins, fats, carbs, kcal FROM products WHERE id=%s', (product_id,)).fetchone()
        if not product:
            raise HTTPException(status_code=404, detail='Product not found')
        sizes = conn.execute('''SELECT id,label,ml,price_delta,sort_order,is_active FROM product_sizes WHERE product_id=%s ORDER BY sort_order, ml''', (product_id,)).fetchall()
        group_ids = [r['group_id'] for r in conn.execute('SELECT group_id FROM product_modifier_groups WHERE product_id=%s ORDER BY group_id', (product_id,)).fetchall()]
    return {'productId': product_id, 'sizes': [{'id': s['id'], 'label': s['label'], 'ml': s['ml'], 'priceDelta': money(s['price_delta']), 'sortOrder': s['sort_order'], 'isActive': s['is_active']} for s in sizes], 'modifierGroupIds': group_ids, 'nutrition': {'weightG': money(product['weight_g']) if product['weight_g'] is not None else None, 'proteins': money(product['proteins']) if product['proteins'] is not None else None, 'fats': money(product['fats']) if product['fats'] is not None else None, 'carbs': money(product['carbs']) if product['carbs'] is not None else None, 'kcal': money(product['kcal']) if product['kcal'] is not None else None}}


@app.put('/admin/products/{product_id}/composition')
def update_product_composition(product_id: str, payload: ProductCompositionInput, staff: dict[str, Any] = Depends(staff_guard('admin'))) -> dict[str, Any]:
    with db() as conn:
        if not conn.execute('SELECT 1 FROM products WHERE id=%s', (product_id,)).fetchone():
            raise HTTPException(status_code=404, detail='Product not found')
        known_groups = conn.execute('SELECT id FROM modifier_groups WHERE id = ANY(%s)', (payload.modifier_group_ids,)).fetchall()
        if len(known_groups) != len(set(payload.modifier_group_ids)):
            raise HTTPException(status_code=422, detail='Unknown modifier group')
        conn.execute('UPDATE product_sizes SET is_active = FALSE WHERE product_id = %s', (product_id,))
        for size in payload.sizes:
            conn.execute('''INSERT INTO product_sizes (product_id,id,label,ml,price_delta,sort_order,is_active)
                            VALUES (%s,%s,%s,%s,%s,%s,%s)
                            ON CONFLICT (product_id,id) DO UPDATE SET label=EXCLUDED.label,ml=EXCLUDED.ml,price_delta=EXCLUDED.price_delta,sort_order=EXCLUDED.sort_order,is_active=EXCLUDED.is_active''', (product_id, size.id, size.label, size.ml, size.price_delta, size.sort_order, size.is_active))
        conn.execute('DELETE FROM product_modifier_groups WHERE product_id=%s', (product_id,))
        for group_id in dict.fromkeys(payload.modifier_group_ids):
            conn.execute('INSERT INTO product_modifier_groups (product_id,group_id) VALUES (%s,%s)', (product_id, group_id))
        n = payload.nutrition
        conn.execute('''UPDATE products SET weight_g=%s, proteins=%s, fats=%s, carbs=%s, kcal=%s WHERE id=%s''', (n.weight_g, n.proteins, n.fats, n.carbs, n.kcal, product_id))
    return {'id': product_id, 'status': 'updated'}


@app.get('/admin/modifier-groups')
def admin_modifier_groups(staff: dict[str, Any] = Depends(staff_guard('admin', 'manager'))) -> list[dict[str, Any]]:
    with db() as conn:
        groups = conn.execute('''SELECT id,title,required,sort_order,is_active FROM modifier_groups ORDER BY sort_order,title''').fetchall()
        result = []
        for group in groups:
            options = conn.execute('''SELECT id,title,price_delta,is_default,sort_order,is_active
                                      FROM modifier_options WHERE group_id=%s ORDER BY sort_order,title''', (group['id'],)).fetchall()
            result.append({'id': group['id'], 'title': group['title'], 'required': group['required'], 'sortOrder': group['sort_order'], 'isActive': group['is_active'], 'options': [{'id': o['id'], 'title': o['title'], 'priceDelta': money(o['price_delta']), 'isDefault': o['is_default'], 'sortOrder': o['sort_order'], 'isActive': o['is_active']} for o in options]})
    return result


@app.post('/admin/modifier-groups', status_code=201)
def create_modifier_group(payload: ModifierGroupAdminInput, staff: dict[str, Any] = Depends(staff_guard('admin'))) -> dict[str, Any]:
    with db() as conn:
        conn.execute('''INSERT INTO modifier_groups (id,title,required,sort_order,is_active) VALUES (%s,%s,%s,%s,%s)''', (payload.id, payload.title, payload.required, payload.sort_order, payload.is_active))
    return {'id': payload.id, 'status': 'created'}


@app.put('/admin/modifier-groups/{group_id}')
def update_modifier_group(group_id: str, payload: ModifierGroupAdminInput, staff: dict[str, Any] = Depends(staff_guard('admin'))) -> dict[str, Any]:
    if group_id != payload.id:
        raise HTTPException(status_code=422, detail='Modifier group id cannot be changed')
    with db() as conn:
        row = conn.execute('''UPDATE modifier_groups SET title=%s,required=%s,sort_order=%s,is_active=%s WHERE id=%s RETURNING id''', (payload.title, payload.required, payload.sort_order, payload.is_active, group_id)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail='Modifier group not found')
    return {'id': group_id, 'status': 'updated'}


@app.post('/admin/modifier-groups/{group_id}/options', status_code=201)
def create_modifier_option(group_id: str, payload: ModifierOptionAdminInput, staff: dict[str, Any] = Depends(staff_guard('admin'))) -> dict[str, Any]:
    with db() as conn:
        if not conn.execute('SELECT 1 FROM modifier_groups WHERE id=%s', (group_id,)).fetchone():
            raise HTTPException(status_code=404, detail='Modifier group not found')
        conn.execute('''INSERT INTO modifier_options (group_id,id,title,price_delta,is_default,sort_order,is_active)
                        VALUES (%s,%s,%s,%s,%s,%s,%s)''', (group_id, payload.id, payload.title, payload.price_delta, payload.is_default, payload.sort_order, payload.is_active))
    return {'groupId': group_id, 'id': payload.id, 'status': 'created'}


@app.put('/admin/modifier-groups/{group_id}/options/{option_id}')
def update_modifier_option(group_id: str, option_id: str, payload: ModifierOptionAdminInput, staff: dict[str, Any] = Depends(staff_guard('admin'))) -> dict[str, Any]:
    if option_id != payload.id:
        raise HTTPException(status_code=422, detail='Modifier option id cannot be changed')
    with db() as conn:
        row = conn.execute('''UPDATE modifier_options SET title=%s,price_delta=%s,is_default=%s,sort_order=%s,is_active=%s
                              WHERE group_id=%s AND id=%s RETURNING id''', (payload.title, payload.price_delta, payload.is_default, payload.sort_order, payload.is_active, group_id, option_id)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail='Modifier option not found')
    return {'groupId': group_id, 'id': option_id, 'status': 'updated'}


@app.get('/admin/staff')
def admin_staff(staff: dict[str, Any] = Depends(staff_guard('admin'))) -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute(
            '''SELECT s.id, s.email, s.role, s.is_active, s.created_at,
                      COALESCE(array_agg(a.venue_id) FILTER (WHERE a.venue_id IS NOT NULL), '{}') AS venue_ids
               FROM staff_users s LEFT JOIN staff_venue_access a ON a.staff_id = s.id
               GROUP BY s.id ORDER BY s.created_at''',
        ).fetchall()
    return [{
        'id': row['id'], 'email': row['email'], 'role': row['role'],
        'isActive': row['is_active'], 'venueIds': row['venue_ids'],
    } for row in rows]


@app.post('/admin/staff', status_code=201)
def create_staff(
    payload: StaffCreateRequest,
    staff: dict[str, Any] = Depends(staff_guard('admin')),
) -> dict[str, Any]:
    if payload.role not in {'admin', 'manager', 'barista'}:
        raise HTTPException(status_code=422, detail='Unknown staff role')
    email = payload.email.strip().lower()
    if not email or '@' not in email:
        raise HTTPException(status_code=422, detail='A valid email is required')
    staff_id = f'staff_{uuid.uuid4().hex}'
    with db() as conn:
        known_venues = conn.execute('SELECT id FROM venues WHERE id = ANY(%s)', (payload.venue_ids,)).fetchall()
        if len(known_venues) != len(set(payload.venue_ids)):
            raise HTTPException(status_code=422, detail='Unknown venue in access list')
        existing = conn.execute('SELECT 1 FROM staff_users WHERE email = %s', (email,)).fetchone()
        if existing:
            raise HTTPException(status_code=409, detail='This email already has staff access')
        conn.execute(
            '''INSERT INTO staff_users (id, email, password_hash, role)
               VALUES (%s, %s, %s, %s)''',
            (staff_id, email, hash_password(payload.password), payload.role),
        )
        for venue_id in set(payload.venue_ids):
            conn.execute(
                'INSERT INTO staff_venue_access (staff_id, venue_id) VALUES (%s, %s)',
                (staff_id, venue_id),
            )
    return {'id': staff_id, 'email': email, 'role': payload.role, 'venueIds': payload.venue_ids}


@app.patch('/admin/staff/{staff_id}')
def update_staff(
    staff_id: str,
    payload: StaffUpdateRequest,
    staff: dict[str, Any] = Depends(staff_guard('admin')),
) -> dict[str, Any]:
    values = payload.model_dump(exclude_unset=True)
    if not values:
        raise HTTPException(status_code=422, detail='No fields to update')
    if staff_id == staff['id'] and values.get('is_active') is False:
        raise HTTPException(status_code=422, detail='You cannot deactivate your own account')
    if values.get('role') and values['role'] not in {'admin', 'manager', 'barista'}:
        raise HTTPException(status_code=422, detail='Unknown staff role')
    with db() as conn:
        if not conn.execute('SELECT 1 FROM staff_users WHERE id = %s', (staff_id,)).fetchone():
            raise HTTPException(status_code=404, detail='Staff member not found')
        if 'venue_ids' in values:
            known = conn.execute('SELECT id FROM venues WHERE id = ANY(%s)', (values['venue_ids'],)).fetchall()
            if len(known) != len(set(values['venue_ids'])):
                raise HTTPException(status_code=422, detail='Unknown venue in access list')
            conn.execute('DELETE FROM staff_venue_access WHERE staff_id = %s', (staff_id,))
            for venue_id in set(values['venue_ids']):
                conn.execute('INSERT INTO staff_venue_access (staff_id, venue_id) VALUES (%s,%s)', (staff_id, venue_id))
        assignments = []
        params: list[Any] = []
        for key in ('role', 'is_active'):
            if key in values:
                assignments.append(f'{key} = %s')
                params.append(values[key])
        if assignments:
            conn.execute(f"UPDATE staff_users SET {', '.join(assignments)} WHERE id = %s", [*params, staff_id])
    return {'id': staff_id, 'status': 'updated'}


@app.post('/admin/media', status_code=201)
async def upload_media(
    file: UploadFile = File(...),
    alt_text: str | None = None,
    staff: dict[str, Any] = Depends(staff_guard('admin', 'manager')),
) -> dict[str, Any]:
    if file.content_type not in {'image/png', 'image/jpeg', 'image/webp'}:
        raise HTTPException(status_code=415, detail='Only PNG, JPEG and WebP images are allowed')
    content = await file.read()
    if not content or len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail='Image must be between 1 byte and 10 MB')
    try:
        with Image.open(BytesIO(content)) as image:
            width, height = image.size
            if image.mode not in ('RGB', 'RGBA'):
                image = image.convert('RGBA' if 'transparency' in image.info else 'RGB')
            optimized = BytesIO()
            image.save(optimized, format='WEBP', quality=82, method=6)
            content = optimized.getvalue()
    except UnidentifiedImageError as error:
        raise HTTPException(status_code=422, detail='The uploaded content is not a valid image') from error
    required = ('S3_ENDPOINT', 'S3_BUCKET', 'S3_ACCESS_KEY', 'S3_SECRET_KEY')
    if not all(os.environ.get(name) for name in required):
        raise HTTPException(status_code=503, detail='Object Storage is not configured')
    content_type = 'image/webp'
    object_key = f'uploads/{uuid.uuid4()}.webp'
    try:
        import boto3
        client = boto3.client(
            's3', endpoint_url=os.environ['S3_ENDPOINT'],
            aws_access_key_id=os.environ['S3_ACCESS_KEY'],
            aws_secret_access_key=os.environ['S3_SECRET_KEY'],
            region_name=os.environ.get('S3_REGION', 'ru-central1'),
        )
        client.put_object(
            Bucket=os.environ['S3_BUCKET'], Key=object_key, Body=content,
            ContentType=content_type, CacheControl='public, max-age=31536000, immutable',
        )
    except Exception as error:
        raise HTTPException(status_code=502, detail='Object Storage upload failed') from error
    media_id = f'media_{uuid.uuid4().hex}'
    with db() as conn:
        conn.execute(
            '''INSERT INTO media_assets (id, object_key, content_type, width, height, byte_size, alt_text)
               VALUES (%s, %s, %s, %s, %s, %s, %s)''',
            (media_id, object_key, content_type, width, height, len(content), alt_text),
        )
    return {
        'id': media_id, 'objectKey': object_key, 'imageUrl': media_url(object_key),
        'width': width, 'height': height, 'altText': alt_text,
    }


@app.post('/admin/orders/{order_id}/status')
def update_order_status(
    order_id: str,
    payload: OrderStatusUpdate,
    staff: dict[str, Any] = Depends(staff_guard('admin', 'manager', 'barista')),
) -> dict[str, Any]:
    transitions = {
        'confirmed': {'preparing'},
        'preparing': {'ready'},
        'ready': {'issued'},
    }
    with db() as conn:
        order = conn.execute('SELECT id, venue_id, status FROM orders WHERE id = %s', (order_id,)).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail='Order not found')
        if payload.status not in transitions.get(order['status'], set()):
            raise HTTPException(status_code=409, detail='Invalid order status transition')
        assert_staff_venue_access(conn, staff, order['venue_id'])
        conn.execute(
            'UPDATE orders SET status = %s, updated_at = NOW() WHERE id = %s',
            (payload.status, order_id),
        )
        conn.execute(
            '''INSERT INTO order_status_events (id, order_id, from_status, to_status, actor_type, actor_id)
               VALUES (%s, %s, %s, %s, 'staff', %s)''',
            (str(uuid.uuid4()), order_id, order['status'], payload.status, staff['id']),
        )
        bonus_earned = _award_order_bonuses(conn, order_id) if payload.status == 'issued' else 0
    return {'id': order_id, 'status': payload.status, 'bonusEarned': bonus_earned}


@app.get('/admin-legacy', response_class=HTMLResponse, include_in_schema=False)
def admin_page() -> str:
    """Small operational UI. Its API is role-protected; no credentials are embedded."""
    return '''<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Кофе Мама — управление</title><style>
*{box-sizing:border-box}body{margin:0;background:#f7f2e9;color:#1a1a1a;font:16px Manrope,Arial,sans-serif}.wrap{max-width:860px;margin:0 auto;padding:32px 20px}h1{color:#1b4d3e}.card{background:#fff;border:1px solid #e8e1d6;border-radius:18px;padding:20px;margin:16px 0}.login{display:grid;gap:10px;max-width:360px}input{padding:12px;border:1px solid #c8d9cc;border-radius:10px;font:inherit}button{border:0;border-radius:10px;padding:11px 15px;background:#1b4d3e;color:#fff;font:inherit;cursor:pointer}button.secondary{background:#a8c5b0;color:#1a1a1a}.row{display:grid;grid-template-columns:1fr 110px auto;gap:12px;align-items:center;border-top:1px solid #e8e1d6;padding:12px 0}.row:first-child{border-top:0}.muted{color:#5c5c5c}.error{color:#c45c4a;min-height:24px}@media(max-width:560px){.row{grid-template-columns:1fr 90px}.row button{grid-column:1/-1}}</style></head><body><main class="wrap">
<h1>Кофе Мама · управление меню</h1><p class="muted">Только для сотрудников. Изменения публикуются в меню выбранной точки без обновления приложения.</p>
<section class="card" id="loginCard"><form class="login" id="login"><input id="email" type="email" placeholder="Email" required><input id="password" type="password" placeholder="Пароль" minlength="8" required><button>Войти</button><div id="error" class="error"></div></form></section>
<section class="card" id="menuCard" hidden><h2>Товары</h2><div id="products"></div></section>
</main><script>
let token=sessionStorage.getItem('kofe_staff_token')||'';const $=id=>document.getElementById(id);const api=async(path,opts={})=>{const r=await fetch(path,{...opts,headers:{'Content-Type':'application/json','Authorization':'Bearer '+token,...(opts.headers||{})}});if(!r.ok)throw new Error((await r.json().catch(()=>({}))).detail||'Ошибка запроса');return r.json()};
function showMenu(rows){$('loginCard').hidden=true;$('menuCard').hidden=false;const root=$('products');root.replaceChildren();rows.forEach(p=>{const row=document.createElement('div');row.className='row';const title=document.createElement('div');title.innerHTML='<strong></strong><div class="muted"></div>';title.firstChild.textContent=p.title;title.lastChild.textContent=p.isActive?'Активен':'Скрыт';const price=document.createElement('input');price.type='number';price.min='0';price.step='1';price.value=p.price;const save=document.createElement('button');save.textContent='Сохранить';save.onclick=async()=>{try{await api('/admin/products/'+p.id,{method:'PATCH',body:JSON.stringify({price:Number(price.value)})});save.textContent='Готово';setTimeout(()=>save.textContent='Сохранить',1200)}catch(e){$('error').textContent=e.message}};row.append(title,price,save);root.append(row)})}
async function load(){try{showMenu(await api('/admin/products'))}catch(e){token='';sessionStorage.removeItem('kofe_staff_token');$('error').textContent=e.message}}
$('login').onsubmit=async e=>{e.preventDefault();$('error').textContent='';try{const data=await api('/admin/login',{method:'POST',headers:{},body:JSON.stringify({email:$('email').value,password:$('password').value})});token=data.accessToken;sessionStorage.setItem('kofe_staff_token',token);load()}catch(e){$('error').textContent=e.message}};if(token)load();
</script></body></html>'''


@app.get('/admin', include_in_schema=False)
def staff_web() -> FileResponse:
    return FileResponse(Path(__file__).with_name('admin.html'), media_type='text/html; charset=utf-8')


@app.post('/orders', status_code=201)
def create_order(payload: CreateOrderRequest) -> dict[str, Any]:
    if not payload.address_confirmed:
        raise HTTPException(status_code=422, detail='Address confirmation is required')
    with db() as conn:
        existing = conn.execute(
            '''SELECT id, status, total, payment_total, bonus_spent
               FROM orders WHERE idempotency_key = %s''',
            (payload.idempotency_key,),
        ).fetchone()
        if existing:
            return {
                'id': existing['id'], 'status': existing['status'],
                'total': money(existing['total']),
                'paymentTotal': money(existing['payment_total']),
                'bonusSpent': int(existing['bonus_spent'] or 0),
            }
        quote = _apply_loyalty(
            conn,
            _quote(conn, payload),
            payload.bonus_points,
            payload.user_id,
            lock_user=True,
        )
        order_id = str(uuid.uuid4())
        summary = ', '.join(line['title'] for line in quote['items'])[:250]
        conn.execute(
            '''INSERT INTO orders
               (id, user_id, venue_id, status, total, payment_total, bonus_spent,
                subtotal, discount, summary_line, comment, promo_code,
                address_confirmed, idempotency_key)
               VALUES (%s, %s, %s, 'pending_payment', %s, %s, %s, %s, %s, %s,
                       %s, %s, TRUE, %s)''',
            (order_id, payload.user_id, payload.venue_id, quote['total'], quote['paymentTotal'],
             quote['bonusSpent'], quote['subtotal'], quote['discount'], summary,
             payload.comment, payload.promo_code, payload.idempotency_key),
        )
        if quote['bonusSpent'] > 0:
            balance_after = quote['bonusBalance'] - quote['bonusSpent']
            conn.execute(
                'UPDATE users SET bonus_balance = %s WHERE id = %s',
                (balance_after, payload.user_id),
            )
            conn.execute(
                '''INSERT INTO bonus_transactions
                   (id, user_id, order_id, kind, points, balance_after, description)
                   VALUES (%s, %s, %s, 'spend', %s, %s, %s)''',
                (
                    str(uuid.uuid4()), payload.user_id, order_id,
                    -quote['bonusSpent'], balance_after, 'Списание на заказ',
                ),
            )
        for line in quote['items']:
            item_id = str(uuid.uuid4())
            conn.execute(
                '''INSERT INTO order_items (id, order_id, product_id, title_snapshot, qty, unit_price, line_total)
                   VALUES (%s, %s, %s, %s, %s, %s, %s)''',
                (item_id, order_id, line['productId'], line['title'], line['qty'], line['unitPrice'], line['lineTotal']),
            )
            for modifier in line['modifiers']:
                conn.execute(
                    '''INSERT INTO order_item_modifiers
                       (id, order_item_id, group_id, group_title, option_id, option_title, price_delta)
                       VALUES (%s, %s, %s, %s, %s, %s, %s)''',
                    (str(uuid.uuid4()), item_id, modifier['groupId'], modifier['groupTitle'],
                     modifier['optionId'], modifier['optionTitle'], modifier['priceDelta']),
                )
        conn.execute(
            '''INSERT INTO order_status_events (id, order_id, to_status, actor_type)
               VALUES (%s, %s, 'pending_payment', 'customer')''',
            (str(uuid.uuid4()), order_id),
        )
        return {
            'id': order_id,
            'status': 'pending_payment',
            'total': quote['total'],
            'paymentTotal': quote['paymentTotal'],
            'bonusSpent': quote['bonusSpent'],
        }


@app.post('/orders/{order_id}/payment')
async def start_yookassa_payment(order_id: str, _: PaymentStartRequest) -> dict[str, Any]:
    """Create/reuse one redirect payment; only a verified provider response confirms it."""
    shop_id, secret_key, return_url = yookassa_settings()
    with db() as conn:
        order = conn.execute(
            'SELECT id, total, payment_total, status FROM orders WHERE id = %s', (order_id,),
        ).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail='Order not found')
        if order['status'] != 'pending_payment':
            raise HTTPException(status_code=409, detail='Order is no longer awaiting payment')
        payment = conn.execute(
            '''SELECT id, idempotency_key, confirmation_url, external_id, status
               FROM payments WHERE order_id = %s AND provider = 'yookassa'
               ORDER BY created_at DESC LIMIT 1''',
            (order_id,),
        ).fetchone()
        if payment and payment['confirmation_url']:
            return {
                'paymentId': payment['external_id'], 'confirmationUrl': payment['confirmation_url'],
                'status': payment['status'],
            }
        if payment:
            payment_id, idempotency_key = payment['id'], payment['idempotency_key']
        else:
            payment_id, idempotency_key = str(uuid.uuid4()), str(uuid.uuid4())
            conn.execute(
                '''INSERT INTO payments (id, order_id, provider, amount, status, idempotency_key)
                   VALUES (%s, %s, 'yookassa', %s, 'creating', %s)''',
                (payment_id, order_id, order['payment_total'], idempotency_key),
            )

    import httpx
    body = {
        'amount': {'value': f"{money(order['payment_total']):.2f}", 'currency': 'RUB'},
        'capture': True,
        'confirmation': {'type': 'redirect', 'return_url': return_url},
        'description': f'Заказ Кофе Мама {order_id}',
        'metadata': {'order_id': order_id},
    }
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(
                'https://api.yookassa.ru/v3/payments', json=body,
                auth=(shop_id, secret_key), headers={'Idempotence-Key': idempotency_key},
            )
        response.raise_for_status()
        remote = response.json()
    except httpx.HTTPStatusError as error:
        # YooKassa returns a public error code/description here. Keep the
        # secret and full authorization data out of both logs and responses.
        try:
            provider_error = error.response.json()
        except ValueError:
            provider_error = {}
        provider_code = str(provider_error.get('code') or 'unknown_error')[:80]
        print(
            f'YooKassa payment creation rejected: status={error.response.status_code} '
            f'code={provider_code}',
            flush=True,
        )
        with db() as conn:
            conn.execute('UPDATE payments SET status = %s, updated_at = NOW() WHERE id = %s', ('failed', payment_id))
        _cancel_failed_payment(order_id)
        raise HTTPException(
            status_code=502,
            detail=f'YooKassa rejected the payment ({provider_code})',
        ) from error
    except Exception as error:
        print(
            f'YooKassa payment creation failed before response: '
            f'{type(error).__name__}: {str(error)[:200]}',
            flush=True,
        )
        with db() as conn:
            conn.execute('UPDATE payments SET status = %s, updated_at = NOW() WHERE id = %s', ('failed', payment_id))
        raise HTTPException(status_code=502, detail='Could not create YooKassa payment') from error

    confirmation_url = ((remote.get('confirmation') or {}).get('confirmation_url'))
    if not remote.get('id') or not confirmation_url:
        raise HTTPException(status_code=502, detail='YooKassa did not return a redirect URL')
    with db() as conn:
        conn.execute(
            '''UPDATE payments SET external_id = %s, status = %s, confirmation_url = %s,
               raw_payload = %s, updated_at = NOW() WHERE id = %s''',
            (remote['id'], remote.get('status', 'pending'), confirmation_url, json.dumps(remote), payment_id),
        )
    return {'paymentId': remote['id'], 'confirmationUrl': confirmation_url, 'status': remote.get('status', 'pending')}


@app.post('/webhooks/yookassa', status_code=200)
async def yookassa_webhook(payload: dict[str, Any]) -> None:
    """Webhook payload is verified against YooKassa API before any order state changes."""
    external_id = (payload.get('object') or {}).get('id')
    if not external_id:
        raise HTTPException(status_code=422, detail='Missing YooKassa payment id')
    remote = await fetch_yookassa_payment(external_id)
    persist_yookassa_state(remote)


@app.get('/payment-return', response_class=HTMLResponse, include_in_schema=False)
def yookassa_payment_return() -> str:
    """Neutral browser return page until the mobile app receives an App Link."""
    return '''<!doctype html><html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Кофе Мама — оплата</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#f7f2e9;color:#173d32;font:16px/1.5 Arial,sans-serif}.card{max-width:440px;margin:24px;padding:32px;border-radius:24px;background:#fff;text-align:center;box-shadow:0 14px 40px #173d3215}h1{margin:0 0 12px;font-size:26px}p{margin:0;color:#526159}.mark{width:52px;height:52px;margin:0 auto 20px;border-radius:50%;display:grid;place-items:center;background:#d7b78b;font-size:25px}</style>
</head><body><main class="card"><div class="mark">✓</div><h1>Вернитесь в приложение</h1><p>Оплата обрабатывается ЮKassa. Откройте «Кофе Мама» — приложение проверит статус автоматически.</p></main></body></html>'''


@app.post('/orders/{order_id}/review', status_code=201)
def leave_review(order_id: str, payload: ReviewRequest) -> dict[str, str]:
    with db() as conn:
        order = conn.execute('SELECT id FROM orders WHERE id = %s', (order_id,)).fetchone()
        if not order:
            raise HTTPException(status_code=404, detail='Order not found')
        conn.execute(
            '''INSERT INTO reviews (id, order_id, food_rating, service_rating, text)
               VALUES (%s, %s, %s, %s, %s)
               ON CONFLICT (order_id) DO UPDATE SET food_rating = EXCLUDED.food_rating,
                 service_rating = EXCLUDED.service_rating, text = EXCLUDED.text''',
            (str(uuid.uuid4()), order_id, payload.food_rating, payload.service_rating, payload.text),
        )
    return {'status': 'saved'}


@app.get("/products/{product_id}")
def product(product_id: str, venue_id: str | None = Query(default=None)) -> dict[str, Any]:
    """Return a PDP using the same price and availability rules as /menu.

    `venue_id` is optional for legacy callers, but mobile PDP always supplies
    it. Without it a venue override (for example, a 290 ₽ bottle at one
    location and 289 ₽ elsewhere) cannot be represented correctly.
    """
    with db() as conn:
        if venue_id:
            available = conn.execute(
                '''SELECT 1
                   FROM products p
                   LEFT JOIN venue_product_overrides vp
                     ON vp.product_id = p.id AND vp.venue_id = %s
                   WHERE p.id = %s AND p.is_active = TRUE
                     AND COALESCE(vp.is_available, TRUE) = TRUE
                     AND NOT EXISTS (
                       SELECT 1 FROM product_stop_list s
                       WHERE s.venue_id = %s AND s.product_id = p.id AND s.is_stopped = TRUE
                     )''',
                (venue_id, product_id, venue_id),
            ).fetchone()
            if not available:
                raise HTTPException(status_code=404, detail="Product is unavailable at this venue")
        item = _load_product(conn, product_id, venue_id)
    if not item:
        raise HTTPException(status_code=404, detail="Product not found")
    return item


@app.get("/promo-slides")
def promo_slides() -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute(
            """
            SELECT p.id, p.title, p.body, p.cta_url, m.object_key
            FROM promo_slides p
            LEFT JOIN media_assets m ON m.id = p.image_media_id
            WHERE p.is_active = TRUE
            ORDER BY p.sort_order
            """
        ).fetchall()
    return [
        {
            "id": r["id"],
            "title": r["title"],
            "body": r["body"],
            "ctaUrl": r["cta_url"],
            "imageUrl": media_url(r["object_key"]),
        }
        for r in rows
    ]


@app.get("/me")
def me() -> dict[str, Any]:
    with db() as conn:
        u = conn.execute(
            """
            SELECT id, name, phone, email, birth_date, bonus_balance
            FROM users WHERE id = 'u_demo'
            """
        ).fetchone()
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "id": u["id"],
        "name": u["name"],
        "phone": u["phone"],
        "email": u["email"],
        "birthDate": u["birth_date"].isoformat() if u["birth_date"] else None,
        "bonusBalance": u["bonus_balance"],
    }


@app.get("/orders")
def orders() -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute(
            """
            SELECT id, status, total, payment_total, bonus_spent, bonus_earned,
                   created_at, summary_line, venue_id
            FROM orders ORDER BY created_at DESC
            """
        ).fetchall()
    return [
        {
            "id": r["id"],
            "status": r["status"],
            "total": money(r["total"]),
            "paymentTotal": money(r["payment_total"]),
            "bonusSpent": int(r["bonus_spent"] or 0),
            "bonusEarned": int(r["bonus_earned"] or 0),
            "createdAt": r["created_at"].isoformat(),
            "summaryLine": r["summary_line"],
            "venueId": r["venue_id"],
        }
        for r in rows
    ]


@app.get("/orders/{order_id}")
def order(order_id: str) -> dict[str, Any]:
    with db() as conn:
        r = conn.execute(
            """
            SELECT id, status, total, payment_total, bonus_spent, bonus_earned,
                   created_at, summary_line, venue_id
            FROM orders WHERE id = %s
            """,
            (order_id,),
        ).fetchone()
    if not r:
        raise HTTPException(status_code=404, detail="Order not found")
    return {
        "id": r["id"],
        "status": r["status"],
        "total": money(r["total"]),
        "paymentTotal": money(r["payment_total"]),
        "bonusSpent": int(r["bonus_spent"] or 0),
        "bonusEarned": int(r["bonus_earned"] or 0),
        "createdAt": r["created_at"].isoformat(),
        "summaryLine": r["summary_line"],
        "venueId": r["venue_id"],
    }


@app.get('/orders/{order_id}/payment-status')
async def order_payment_status(order_id: str) -> dict[str, Any]:
    """Reconcile a redirect payment after the customer returns to the app.

    Webhooks remain the primary notification channel. This endpoint gives the
    mobile client a safe manual refresh while the VPS has no public HTTPS URL
    for receiving a YooKassa webhook.
    """
    with db() as conn:
        order_row = conn.execute(
            'SELECT id, status FROM orders WHERE id = %s', (order_id,),
        ).fetchone()
        if not order_row:
            raise HTTPException(status_code=404, detail='Order not found')
        payment = conn.execute(
            '''SELECT external_id, status FROM payments
               WHERE order_id = %s AND provider = 'yookassa'
               ORDER BY created_at DESC LIMIT 1''',
            (order_id,),
        ).fetchone()

    payment_status = payment['status'] if payment else 'not_created'
    if payment and payment['external_id']:
        remote = await fetch_yookassa_payment(payment['external_id'])
        payment_status = persist_yookassa_state(remote)

    with db() as conn:
        refreshed = conn.execute(
            'SELECT status FROM orders WHERE id = %s', (order_id,),
        ).fetchone()
    return {
        'orderId': order_id,
        'orderStatus': refreshed['status'] if refreshed else order_row['status'],
        'paymentStatus': payment_status,
    }


@app.get("/notifications")
def notifications() -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute(
            """
            SELECT id, type, title, body, created_at, order_id
            FROM notifications ORDER BY created_at DESC
            """
        ).fetchall()
    return [
        {
            "id": r["id"],
            "type": r["type"],
            "title": r["title"],
            "body": r["body"],
            "createdAt": r["created_at"].isoformat(),
            "orderId": r["order_id"],
        }
        for r in rows
    ]
