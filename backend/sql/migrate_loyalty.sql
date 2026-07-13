-- Server-authoritative loyalty ledger.
-- One bonus equals one rouble. Bonuses may cover the order down to 1 RUB.

ALTER TABLE orders ADD COLUMN IF NOT EXISTS bonus_spent INT NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS bonus_earned INT NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_total NUMERIC(10,2);

UPDATE orders SET payment_total = total WHERE payment_total IS NULL;

ALTER TABLE orders ALTER COLUMN payment_total SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'orders_bonus_spent_nonnegative'
  ) THEN
    ALTER TABLE orders ADD CONSTRAINT orders_bonus_spent_nonnegative CHECK (bonus_spent >= 0);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'orders_bonus_earned_nonnegative'
  ) THEN
    ALTER TABLE orders ADD CONSTRAINT orders_bonus_earned_nonnegative CHECK (bonus_earned >= 0);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'orders_payment_total_minimum'
  ) THEN
    ALTER TABLE orders ADD CONSTRAINT orders_payment_total_minimum CHECK (payment_total >= 1);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS bonus_transactions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  order_id TEXT REFERENCES orders(id),
  kind TEXT NOT NULL CHECK (kind IN ('spend', 'earn', 'refund', 'adjustment')),
  points INT NOT NULL CHECK (points <> 0),
  balance_after INT NOT NULL CHECK (balance_after >= 0),
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (order_id, kind)
);

CREATE INDEX IF NOT EXISTS bonus_transactions_user_created_idx
  ON bonus_transactions(user_id, created_at DESC);

CREATE OR REPLACE VIEW admin_daily_venue_stats AS
SELECT
  date_trunc('day', created_at)::date AS day,
  venue_id,
  COUNT(*) FILTER (WHERE status NOT IN ('cancelled')) AS orders_count,
  COALESCE(SUM(payment_total) FILTER (WHERE status NOT IN ('cancelled')), 0) AS revenue,
  COUNT(*) FILTER (WHERE status IN ('pending_payment', 'confirmed', 'preparing', 'ready')) AS active_orders,
  COUNT(*) FILTER (WHERE status = 'issued') AS issued_orders
FROM orders
GROUP BY 1, 2;
