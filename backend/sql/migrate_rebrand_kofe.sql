-- Rebrand all customer-visible database content to «Кофе».
-- Technical identifiers and historical foreign keys intentionally stay unchanged.

UPDATE products
SET title = REPLACE(REPLACE(title, 'КОФЕ МАМА', 'КОФЕ'), 'Кофе Мама', 'Кофе'),
    description = REPLACE(REPLACE(description, 'КОФЕ МАМА', 'КОФЕ'), 'Кофе Мама', 'Кофе');

UPDATE categories
SET title = REPLACE(REPLACE(title, 'КОФЕ МАМА', 'КОФЕ'), 'Кофе Мама', 'Кофе');

UPDATE promo_slides
SET title = REPLACE(REPLACE(title, 'КОФЕ МАМА', 'КОФЕ'), 'Кофе Мама', 'Кофе'),
    body = REPLACE(REPLACE(body, 'КОФЕ МАМА', 'КОФЕ'), 'Кофе Мама', 'Кофе');

UPDATE notifications
SET title = REPLACE(REPLACE(title, 'КОФЕ МАМА', 'КОФЕ'), 'Кофе Мама', 'Кофе'),
    body = REPLACE(REPLACE(body, 'КОФЕ МАМА', 'КОФЕ'), 'Кофе Мама', 'Кофе');

UPDATE media_assets
SET alt_text = REPLACE(REPLACE(alt_text, 'КОФЕ МАМА', 'КОФЕ'), 'Кофе Мама', 'Кофе')
WHERE alt_text IS NOT NULL;
