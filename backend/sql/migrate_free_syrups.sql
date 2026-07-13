-- All syrup options are complimentary across the network.
-- Safe to run repeatedly on an existing database.

UPDATE modifier_options
SET price_delta = 0
WHERE group_id = 'syrup';

UPDATE venue_modifier_option_overrides
SET price_delta = 0,
    updated_at = NOW()
WHERE group_id = 'syrup'
  AND price_delta IS DISTINCT FROM 0;
