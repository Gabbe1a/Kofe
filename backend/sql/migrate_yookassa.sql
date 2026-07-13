-- YooKassa redirect payment state. Secrets remain in ignored environment files.

ALTER TABLE payments ADD COLUMN IF NOT EXISTS confirmation_url TEXT;
CREATE INDEX IF NOT EXISTS payments_order_id_idx ON payments(order_id);
