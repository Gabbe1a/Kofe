-- Operational admin: per-venue assortment/prices and dashboard aggregates.

CREATE TABLE IF NOT EXISTS venue_product_overrides (
  venue_id TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  price NUMERIC(10,2),
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (venue_id, product_id),
  CHECK (price IS NULL OR price >= 0)
);

CREATE TABLE IF NOT EXISTS venue_modifier_option_overrides (
  venue_id TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  group_id TEXT NOT NULL,
  option_id TEXT NOT NULL,
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  price_delta NUMERIC(10,2),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (venue_id, group_id, option_id),
  FOREIGN KEY (group_id, option_id)
    REFERENCES modifier_options(group_id, id) ON DELETE CASCADE,
  CHECK (price_delta IS NULL OR price_delta >= 0)
);

CREATE INDEX IF NOT EXISTS orders_venue_created_idx ON orders(venue_id, created_at DESC);
CREATE INDEX IF NOT EXISTS orders_status_created_idx ON orders(status, created_at DESC);

CREATE OR REPLACE VIEW admin_daily_venue_stats AS
SELECT
  date_trunc('day', created_at)::date AS day,
  venue_id,
  COUNT(*) FILTER (WHERE status NOT IN ('cancelled')) AS orders_count,
  COALESCE(SUM(total) FILTER (WHERE status NOT IN ('cancelled')), 0) AS revenue,
  COUNT(*) FILTER (WHERE status IN ('pending_payment', 'confirmed', 'preparing', 'ready')) AS active_orders,
  COUNT(*) FILTER (WHERE status = 'issued') AS issued_orders
FROM orders
GROUP BY 1, 2;
