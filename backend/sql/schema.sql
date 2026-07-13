-- Kofe Mama — schema (test VPS)

CREATE TABLE cities (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE venues (
  id TEXT PRIMARY KEY,
  city_id TEXT NOT NULL REFERENCES cities(id),
  short_name TEXT NOT NULL,
  full_address TEXT NOT NULL,
  phone TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL
);

CREATE TABLE venue_hours (
  id SERIAL PRIMARY KEY,
  venue_id TEXT NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  days_label TEXT NOT NULL,
  open_time TEXT NOT NULL,
  close_time TEXT NOT NULL
);

CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  parent_id TEXT REFERENCES categories(id),
  sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE products (
  id TEXT PRIMARY KEY,
  category_id TEXT NOT NULL REFERENCES categories(id),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  price NUMERIC(10, 2) NOT NULL,
  image_asset TEXT,
  weight_label TEXT,
  featured BOOLEAN NOT NULL DEFAULT FALSE,
  weight_g NUMERIC(10, 2),
  proteins NUMERIC(10, 2),
  fats NUMERIC(10, 2),
  carbs NUMERIC(10, 2),
  kcal NUMERIC(10, 2)
);

CREATE TABLE product_sizes (
  id TEXT NOT NULL,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  ml INT NOT NULL,
  price_delta NUMERIC(10, 2) NOT NULL DEFAULT 0,
  PRIMARY KEY (product_id, id)
);

CREATE TABLE modifier_groups (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  required BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE modifier_options (
  id TEXT NOT NULL,
  group_id TEXT NOT NULL REFERENCES modifier_groups(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  price_delta NUMERIC(10, 2) NOT NULL DEFAULT 0,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (group_id, id)
);

CREATE TABLE product_modifier_groups (
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  group_id TEXT NOT NULL REFERENCES modifier_groups(id) ON DELETE CASCADE,
  PRIMARY KEY (product_id, group_id)
);

CREATE TABLE promo_slides (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  cta_url TEXT,
  image_asset TEXT,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NOT NULL UNIQUE,
  email TEXT,
  birth_date DATE,
  bonus_balance INT NOT NULL DEFAULT 0
);

CREATE TABLE orders (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES users(id),
  venue_id TEXT REFERENCES venues(id),
  status TEXT NOT NULL,
  total NUMERIC(10, 2) NOT NULL,
  payment_total NUMERIC(10, 2) NOT NULL CHECK (payment_total >= 1),
  bonus_spent INT NOT NULL DEFAULT 0 CHECK (bonus_spent >= 0),
  bonus_earned INT NOT NULL DEFAULT 0 CHECK (bonus_earned >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  summary_line TEXT
);

CREATE TABLE bonus_transactions (
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

CREATE INDEX bonus_transactions_user_created_idx
  ON bonus_transactions(user_id, created_at DESC);

CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  order_id TEXT REFERENCES orders(id)
);
