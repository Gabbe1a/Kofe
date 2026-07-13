-- Adds the optional syrup picker to coffee drinks in an existing database.
-- Safe to run more than once.

INSERT INTO modifier_groups (id, title, required)
VALUES ('syrup', 'Выберите сироп', false)
ON CONFLICT (id) DO UPDATE
SET title = EXCLUDED.title,
    required = EXCLUDED.required;

INSERT INTO modifier_options (id, group_id, title, price_delta, is_default)
VALUES
  ('banana', 'syrup', 'Банан', 40, false),
  ('vanilla', 'syrup', 'Ваниль', 40, false),
  ('caramel', 'syrup', 'Карамель', 40, false),
  ('coconut', 'syrup', 'Кокос', 40, false),
  ('cherry', 'syrup', 'Вишня', 40, false)
ON CONFLICT (group_id, id) DO UPDATE
SET title = EXCLUDED.title,
    price_delta = EXCLUDED.price_delta,
    is_default = EXCLUDED.is_default;

INSERT INTO product_modifier_groups (product_id, group_id)
VALUES
  ('p_caramel', 'syrup'),
  ('p_bottle', 'syrup'),
  ('p_capp', 'syrup'),
  ('p_raf', 'syrup')
ON CONFLICT (product_id, group_id) DO NOTHING;
