-- Typical mix: a qualifying store, a store that is imbalanced the wrong way, a store where the two
-- quantities are equal (strict "less than" excludes it), a 2-product store that would qualify but
-- is too small, and a 4-product store whose cheapest product is not the first listed.
INSERT INTO stores (store_id, store_name, location) VALUES
  (5, 'Mall',     'DAL'),
  (1, 'Downtown', 'NYC'),
  (3, 'Airport',  'LAX'),
  (2, 'Uptown',   'NYC'),
  (4, 'Kiosk',    'SFO');

INSERT INTO inventory (inventory_id, store_id, product_name, quantity, price) VALUES
  (1,  1, 'laptop',  2,  1000.00),
  (2,  1, 'mouse',   50, 10.00),
  (3,  1, 'cable',   30, 5.00),
  (4,  2, 'tv',      20, 800.00),
  (5,  2, 'remote',  5,  20.00),
  (6,  2, 'battery', 8,  3.00),
  (7,  3, 'phone',   10, 600.00),
  (8,  3, 'case',    10, 15.00),
  (9,  3, 'charger', 25, 25.00),
  (10, 4, 'a',       1,  100.00),
  (11, 4, 'b',       99, 1.00),
  (12, 5, 'watch',   3,  200.00),
  (13, 5, 'strap',   12, 4.00),
  (14, 5, 'box',     7,  2.50),
  (15, 5, 'pin',     4,  9.00);

-- expect: 1,Downtown,NYC,laptop,cable,15.00 | most expensive laptop has 2 units, cheapest cable (5.00, not the 10.00 mouse) has 30: 2 < 30, ratio 30/2 = 15
-- expect: 5,Mall,DAL,watch,box,2.33 | most expensive watch has 3 units, cheapest box (2.50, below strap's 4.00) has 7: 3 < 7, ratio 7/3 = 2.3333 -> 2.33
-- (Uptown: tv has 20 units but battery only 8, wrong direction. Airport: phone 10 vs case 10, equal is not strictly less. Kiosk: only 2 products.)
