-- Human-readable order numbers and immutable item configuration snapshots.

-- These two rows are catalogue demo content from seed.sql, not customer
-- purchases. Remove them from upgraded and freshly initialized environments.
DELETE FROM notifications WHERE order_id IN ('55743', '18206');
DELETE FROM orders WHERE id IN ('55743', '18206') AND idempotency_key IS NULL;

CREATE SEQUENCE IF NOT EXISTS orders_public_number_seq START WITH 10001;

ALTER TABLE orders ADD COLUMN IF NOT EXISTS public_number BIGINT;

WITH current_max AS (
  SELECT GREATEST(COALESCE(MAX(public_number), 10000), 10000) AS value
  FROM orders
), numbered AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) AS row_number
  FROM orders
  WHERE public_number IS NULL
)
UPDATE orders AS target
SET public_number = current_max.value + numbered.row_number
FROM current_max, numbered
WHERE target.id = numbered.id;

SELECT setval(
  'orders_public_number_seq',
  GREATEST(COALESCE((SELECT MAX(public_number) FROM orders), 10000), 10000),
  TRUE
);

ALTER TABLE orders
  ALTER COLUMN public_number SET DEFAULT nextval('orders_public_number_seq'),
  ALTER COLUMN public_number SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS orders_public_number_uidx
  ON orders(public_number);

ALTER TABLE order_items ADD COLUMN IF NOT EXISTS size_id TEXT;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS size_label TEXT;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS size_ml INT;
ALTER TABLE order_items
  ADD COLUMN IF NOT EXISTS size_price_delta NUMERIC(10,2) NOT NULL DEFAULT 0;

-- Recover the size of pre-migration orders when the stored unit price matches
-- exactly one current size calculation (or the product has only one size).
-- Ambiguous rows deliberately remain NULL instead of guessing.
WITH modifier_totals AS (
  SELECT order_item_id, COALESCE(SUM(price_delta), 0) AS total
  FROM order_item_modifiers
  GROUP BY order_item_id
), candidates AS (
  SELECT
    item.id AS order_item_id,
    size.id,
    size.label,
    size.ml,
    size.price_delta,
    ABS(
      item.unit_price
      - COALESCE(modifier_totals.total, 0)
      - (COALESCE(venue_price.price, product.price) + size.price_delta)
    ) AS difference,
    COUNT(*) OVER (PARTITION BY item.id) AS size_count,
    ROW_NUMBER() OVER (
      PARTITION BY item.id
      ORDER BY ABS(
        item.unit_price
        - COALESCE(modifier_totals.total, 0)
        - (COALESCE(venue_price.price, product.price) + size.price_delta)
      ), size.sort_order, size.ml
    ) AS position
  FROM order_items AS item
  JOIN orders AS customer_order ON customer_order.id = item.order_id
  JOIN products AS product ON product.id = item.product_id
  JOIN product_sizes AS size
    ON size.product_id = product.id AND size.is_active = TRUE
  LEFT JOIN modifier_totals ON modifier_totals.order_item_id = item.id
  LEFT JOIN venue_product_overrides AS venue_price
    ON venue_price.venue_id = customer_order.venue_id
   AND venue_price.product_id = product.id
  WHERE item.size_id IS NULL
), selected AS (
  SELECT *
  FROM candidates
  WHERE position = 1 AND (difference < 0.01 OR size_count = 1)
)
UPDATE order_items AS item
SET size_id = selected.id,
    size_label = selected.label,
    size_ml = selected.ml,
    size_price_delta = selected.price_delta
FROM selected
WHERE item.id = selected.order_item_id;
