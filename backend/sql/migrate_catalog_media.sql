-- Catalog media and venue availability foundation. Safe to run on the test VPS.

CREATE TABLE IF NOT EXISTS media_assets (
  id TEXT PRIMARY KEY,
  object_key TEXT NOT NULL UNIQUE,
  content_type TEXT NOT NULL,
  width INT,
  height INT,
  byte_size BIGINT,
  alt_text TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE categories ADD COLUMN IF NOT EXISTS image_media_id TEXT REFERENCES media_assets(id);
ALTER TABLE categories ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_media_id TEXT REFERENCES media_assets(id);
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE products ADD COLUMN IF NOT EXISTS sort_order INT NOT NULL DEFAULT 0;
ALTER TABLE promo_slides ADD COLUMN IF NOT EXISTS image_media_id TEXT REFERENCES media_assets(id);
ALTER TABLE promo_slides ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

CREATE TABLE IF NOT EXISTS product_stop_list (
  venue_id TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  is_stopped BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (venue_id, product_id)
);

CREATE TABLE IF NOT EXISTS staff_users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'manager', 'barista')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS staff_venue_access (
  staff_id TEXT NOT NULL REFERENCES staff_users(id) ON DELETE CASCADE,
  venue_id TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  PRIMARY KEY (staff_id, venue_id)
);

CREATE TABLE IF NOT EXISTS venue_settings (
  venue_id TEXT PRIMARY KEY REFERENCES venues(id) ON DELETE CASCADE,
  default_cook_minutes INT NOT NULL DEFAULT 15,
  auto_confirm_on_payment BOOLEAN NOT NULL DEFAULT TRUE
);

-- Existing Flutter asset paths become stable Object Storage keys. Files are
-- uploaded by tools/upload_media.py; API never exposes the legacy paths.
INSERT INTO media_assets (id, object_key, content_type, alt_text) VALUES
  ('media_caramel_frappe', 'products/caramel_frappe_cutout.webp', 'image/webp', 'Карамельный фраппучино'),
  ('media_iced_latte', 'products/iced_latte_cutout.webp', 'image/webp', 'Айс-латте в бутылке'),
  ('media_matcha_latte', 'products/matcha_latte_cutout.webp', 'image/webp', 'Ледяная матча латте'),
  ('media_lemonade', 'products/lemonade_cutout.webp', 'image/webp', 'Лимонад'),
  ('media_cappuccino', 'products/cappuccino_cutout.webp', 'image/webp', 'Капучино'),
  ('media_croissant', 'products/croissant_cutout.webp', 'image/webp', 'Круассан шоколадный'),
  ('media_promo_01', 'promo/promo_01.webp', 'image/webp', 'Франшиза Кофе'),
  ('media_promo_02', 'promo/promo_02.webp', 'image/webp', '100 баллов за сторис'),
  ('media_promo_03', 'promo/promo_03.webp', 'image/webp', 'Амбассадоры'),
  ('media_promo_04', 'promo/promo_04.webp', 'image/webp', 'Социальные сети Кофе')
ON CONFLICT (id) DO UPDATE SET object_key = EXCLUDED.object_key, content_type = EXCLUDED.content_type, alt_text = EXCLUDED.alt_text;

UPDATE products SET image_media_id = CASE id
  WHEN 'p_caramel' THEN 'media_caramel_frappe'
  WHEN 'p_bottle' THEN 'media_iced_latte'
  WHEN 'p_matcha' THEN 'media_matcha_latte'
  WHEN 'p_lemon' THEN 'media_lemonade'
  WHEN 'p_berry_mix' THEN 'media_lemonade'
  WHEN 'p_capp' THEN 'media_cappuccino'
  WHEN 'p_raf' THEN 'media_cappuccino'
  WHEN 'p_croissant' THEN 'media_croissant'
  ELSE NULL
END;

UPDATE promo_slides SET image_media_id = 'media_promo_0' || sort_order::TEXT
WHERE sort_order BETWEEN 1 AND 4;
