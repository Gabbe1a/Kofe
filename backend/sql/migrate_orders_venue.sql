-- Add venue_id to existing orders table (idempotent-ish for VPS migrate)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS venue_id TEXT REFERENCES venues(id);
UPDATE orders SET venue_id = 'v2' WHERE id = '55743' AND venue_id IS NULL;
UPDATE orders SET venue_id = 'v1' WHERE id = '18206' AND venue_id IS NULL;
