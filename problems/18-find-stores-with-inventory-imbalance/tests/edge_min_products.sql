-- The "at least 3 products" boundary: exactly 3 qualifies, 2 does not (though it is imbalanced), 1 does not,
-- and a store with no inventory rows at all does not appear.
INSERT INTO stores (store_id, store_name, location) VALUES
  (40, 'Three', 'A'),
  (41, 'Two',   'B'),
  (42, 'None',  'C'),
  (43, 'One',   'D');

INSERT INTO inventory (inventory_id, store_id, product_name, quantity, price) VALUES
  (1, 40, 'a', 1,  50.00),
  (2, 40, 'b', 4,  20.00),
  (3, 40, 'c', 6,  5.00),
  (4, 41, 'a', 1,  50.00),
  (5, 41, 'b', 9,  1.00),
  (6, 43, 'a', 1,  10.00);

-- expect: 40,Three,A,a,c,6.00 | exactly 3 products qualifies; a (50.00) has 1 unit, c (5.00) has 6: 1 < 6, ratio 6
