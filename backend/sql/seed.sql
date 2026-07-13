-- Seed from Flutter MockData

INSERT INTO cities (id, name) VALUES
  ('rnd', 'Ростов-на-Дону'),
  ('azov', 'Азов'),
  ('sochi', 'Сочи');

INSERT INTO venues (id, city_id, short_name, full_address, phone, lat, lng) VALUES
  ('v1', 'rnd', 'пр-кт Нагибина, 35а', 'Ростов-на-Дону, пр-кт Михаила Нагибина, д. 35а', '+7 (995) 549-80-83', 47.2593653, 39.7170379),
  ('v2', 'rnd', 'ул. Борко, 3/1', 'Ростов-на-Дону, ул. Борко, д. 3/1', '+7 (928) 778-49-26', 47.2806583, 39.7059767),
  ('v3', 'rnd', 'Добровольского, 15', 'Ростов-на-Дону, ул. Добровольского, д. 15', '+7 (952) 573-94-58', 47.2935105, 39.7023244),
  ('v4', 'azov', 'Петровский бульвар, 4', 'Азов, Петровский бульвар, д. 4кГ', '+7 (960) 466-88-87', 47.1119008, 39.4222864),
  ('v5', 'sochi', 'ул. Навагинская, 9Д', 'Сочи, ул. Навагинская, д. 9Д', '+7 (961) 430-77-77', 43.5882194, 39.7234692);

INSERT INTO venue_hours (venue_id, days_label, open_time, close_time) VALUES
  ('v1', 'пн-пт', '07:00', '00:00'),
  ('v1', 'сб-вс', '08:00', '00:00'),
  ('v2', 'пн-вс', '07:00', '23:00'),
  ('v3', 'пн-пт', '07:00', '00:00'),
  ('v3', 'сб-вс', '08:00', '00:00'),
  ('v4', 'пн-вс', '08:00', '22:00'),
  ('v5', 'пн-вс', '08:00', '23:00');

INSERT INTO categories (id, title, sort_order) VALUES
  ('coffee', 'Классический кофе', 1),
  ('signature_cold', 'Холодные фирменные', 2),
  ('signature_hot', 'Горячие фирменные', 3),
  ('lemonades', 'Лимонады', 4),
  ('tea', 'Чаи и чайные напитки', 5),
  ('kids', 'Детское меню', 6),
  ('goods', 'Кофе и товары', 7);

INSERT INTO modifier_groups (id, title, required) VALUES
  ('coffee_blend', 'Выберите кофе', false),
  ('milk', 'Выберите молоко', false),
  ('syrup', 'Выберите сироп', false);

INSERT INTO modifier_options (id, group_id, title, price_delta, is_default) VALUES
  ('decaf', 'coffee_blend', 'Без кофеина', 0, false),
  ('strong', 'coffee_blend', 'Крепкий (70% арабика / 30% робуста)', 0, false),
  ('mild', 'coffee_blend', 'Мягкий (100% арабика)', 0, true),
  ('almond', 'milk', 'Молоко миндальное', 79, false),
  ('coconut', 'milk', 'Молоко кокосовое', 79, false),
  ('lactose_free', 'milk', 'Молоко безлактозное', 79, false),
  ('banana', 'milk', 'Молоко банановое', 79, false),
  ('regular', 'milk', 'Молоко', 0, true),
  ('pistachio', 'milk', 'Молоко фисташковое', 79, false),
  ('banana', 'syrup', 'Банан', 0, false),
  ('vanilla', 'syrup', 'Ваниль', 0, false),
  ('caramel', 'syrup', 'Карамель', 0, false),
  ('coconut', 'syrup', 'Кокос', 0, false),
  ('cherry', 'syrup', 'Вишня', 0, false);

INSERT INTO products (id, category_id, title, description, price, image_asset, weight_label, featured, weight_g, proteins, fats, carbs, kcal) VALUES
  ('p_caramel', 'signature_cold', 'Карамельный фраппучино',
   'Холодный кофе со взбитыми сливками и карамельным топпингом. Фирменный вкус «Кофе».',
   349, 'assets/images/products/caramel_frappe_cutout.png', '400 мл', true, 400, 2.1, 8.4, 42, 248),
  ('p_bottle', 'signature_cold', 'Айс-латте в бутылке',
   'Холодный латте со слоями молока и эспрессо. Удобно взять с собой.',
   289, 'assets/images/products/iced_latte_cutout.png', '350 мл', true, NULL, NULL, NULL, NULL, NULL),
  ('p_matcha', 'tea', 'Ледяная матча латте',
   'Матча на молоке со льдом. Мягкий зелёный вкус без горечи.',
   329, 'assets/images/products/matcha_latte_cutout.png', '400 мл', true, NULL, NULL, NULL, NULL, NULL),
  ('p_lemon', 'lemonades', 'Лимонад Классический',
   'Освежающий напиток со льдом на основе газировки «Лимон-лайм».',
   250, 'assets/images/products/lemonade_cutout.png', '400 мл', true, NULL, NULL, NULL, NULL, NULL),
  ('p_peach_tea', 'lemonades', 'Айс-ти Персик',
   'Холодный чай с персиком и мятой.',
   270, 'assets/images/products/peach_tea_cutout.png', '400 мл', false, NULL, NULL, NULL, NULL, NULL),
  ('p_mojito', 'lemonades', 'Мохито б/а',
   'Безалкогольный мохито с лаймом и мятой.',
   290, 'assets/images/products/mojito_cutout.png', '400 мл', false, NULL, NULL, NULL, NULL, NULL),
  ('p_berry_mix', 'lemonades', 'Ягодный микс',
   'Ягодный лимонад со свежими ягодами.',
   280, 'assets/images/products/lemonade_cutout.png', '400 мл', false, NULL, NULL, NULL, NULL, NULL),
  ('p_capp', 'coffee', 'Капучино',
   'Классический капучино на эспрессо с молочной пеной.',
   259, 'assets/images/products/cappuccino_cutout.png', '300 мл', false, 300, 1.3, 1.3, 16.8, 84),
  ('p_raf', 'signature_hot', 'Авторский раф',
   'Горячий фирменный раф на эспрессо со сливками и ванилью. Мягкий сливочный вкус.',
   319, 'assets/images/products/cappuccino_cutout.png', '300 мл', true, NULL, NULL, NULL, NULL, NULL),
  ('p_croissant', 'goods', 'Круассан шоколадный',
   'Свежая выпечка к кофе. Хрустящий круассан с шоколадом.',
   149, 'assets/images/products/croissant_cutout.png', '80 г', false, NULL, NULL, NULL, NULL, NULL);

INSERT INTO product_sizes (id, product_id, label, ml, price_delta) VALUES
  ('s', 'p_caramel', 'S', 300, 0),
  ('m', 'p_caramel', 'M', 400, 40),
  ('l', 'p_caramel', 'L', 500, 80),
  ('m', 'p_bottle', 'M', 350, 0),
  ('m', 'p_matcha', 'M', 400, 0),
  ('l', 'p_matcha', 'L', 500, 50),
  ('s', 'p_capp', 'S', 250, 0),
  ('m', 'p_capp', 'M', 300, 30),
  ('l', 'p_capp', 'L', 400, 60),
  ('s', 'p_raf', 'S', 250, 0),
  ('m', 'p_raf', 'M', 300, 30),
  ('l', 'p_raf', 'L', 400, 60);

INSERT INTO product_modifier_groups (product_id, group_id) VALUES
  ('p_caramel', 'coffee_blend'),
  ('p_caramel', 'milk'),
  ('p_caramel', 'syrup'),
  ('p_bottle', 'coffee_blend'),
  ('p_bottle', 'milk'),
  ('p_bottle', 'syrup'),
  ('p_capp', 'coffee_blend'),
  ('p_capp', 'milk'),
  ('p_capp', 'syrup'),
  ('p_raf', 'coffee_blend'),
  ('p_raf', 'milk'),
  ('p_raf', 'syrup');

INSERT INTO promo_slides (id, title, body, cta_url, image_asset, sort_order) VALUES
  ('1', 'Франшиза кофейни',
   'Станьте партнёром сети «Кофе». Форматы: остров от 1,3 млн ₽, киоск от 1,4 млн ₽, кофейня с посадкой от 2,3 млн ₽.',
   'https://forms.gle/wswAJZ7mwcumbE5e7', 'assets/images/promo/promo_01.png', 1),
  ('2', '100 баллов за сторис',
   'Купите напиток, отметьте @coffee_mama_rus в сторис, отправьте скрин в VK — получите 100 бонусов. До 3 раз в неделю.',
   NULL, 'assets/images/promo/promo_02.png', 2),
  ('3', 'Стань амбассадором',
   'Делитесь франшизой и получайте до 55 000 ₽ за сделку.',
   'https://ambass.pro/p/729994', 'assets/images/promo/promo_03.png', 3),
  ('4', 'Мы в соцсетях',
   'Меню, сезонные напитки и новости сети — VK и Instagram.',
   'https://vk.com/coffeemama161', 'assets/images/promo/promo_04.png', 4);

INSERT INTO users (id, name, phone, birth_date, bonus_balance) VALUES
  ('u_demo', 'Табунщиков Михаил', '+7 (988) 342-99-00', '2004-03-09', 129);

INSERT INTO orders (id, user_id, venue_id, status, total, payment_total, created_at, summary_line) VALUES
  ('55743', 'u_demo', 'v2', 'Выполнен', 349, 349, '2026-06-27 08:57:00+03', 'Карамельный фраппучино'),
  ('18206', 'u_demo', 'v1', 'Выполнен', 289, 289, '2026-06-25 09:10:00+03', 'Капучино 300мл');

INSERT INTO notifications (id, type, title, body, created_at, order_id) VALUES
  ('n1', 'order', 'Заказ 55743', 'Табунщиков, Ваш заказ №55743 приготовлен.', '2026-06-27 08:45:00+03', '55743'),
  ('n2', 'order', 'Заказ 55743', 'Табунщиков, Ваш заказ №55743 готовится.', '2026-06-27 08:42:00+03', '55743'),
  ('n3', 'promo', 'Оставь машину', 'Гуляй! Пей кофе. Наслаждайся жизнью.', '2026-06-26 20:02:00+03', NULL),
  ('n4', 'order', 'Заказ 18206', 'Заказ №18206 выдан.', '2026-06-25 09:58:00+03', '18206');
