-- Price ties (unspecified in the statement; spec follows the reference tie-break: quantity DESC at both ends).
-- Tie1: two products share the highest price; the one with MORE units (B) is the "most expensive".
-- Tie2: two products share the lowest price; the one with MORE units (Z) is the "cheapest". It also has only
--       two distinct prices over three products (counts must be rows, not distinct prices).
-- Flat: all products share one price, so the same row is both the most expensive and the cheapest.
INSERT INTO stores (store_id, store_name, location) VALUES
  (20, 'Tie1', 'L1'),
  (21, 'Tie2', 'L2'),
  (22, 'Flat', 'L3');

INSERT INTO inventory (inventory_id, store_id, product_name, quantity, price) VALUES
  (1, 20, 'A', 2, 10.00),
  (2, 20, 'B', 5, 10.00),
  (3, 20, 'C', 4, 1.00),
  (4, 21, 'X', 1, 100.00),
  (5, 21, 'Y', 3, 5.00),
  (6, 21, 'Z', 9, 5.00),
  (7, 22, 'P', 5, 7.00),
  (8, 22, 'Q', 3, 7.00),
  (9, 22, 'R', 8, 7.00);

-- expect: 21,Tie2,L2,X,Z,9.00 | X (100.00, 1 unit) is the most expensive; cheapest tie Y/Z at 5.00 resolves to Z (9 units): 1 < 9, ratio 9
-- (Tie1: B (5 units) is the top tie-winner, C has 4 units: 5 < 4 is false, so it is excluded; picking A (2 units) would wrongly include it.
--  Flat: R (8 units) is both ends: 8 < 8 is false, excluded.)
