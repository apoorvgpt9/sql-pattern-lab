-- Tests the output ORDER: imbalance_ratio DESC, then store_name ASC.
-- Alpha and Mid tie exactly (2.00) so only store_name can order them. Alpha2 (5/3 = 1.6667) and
-- Beta2 (167/100 = 1.67) both ROUND to 1.67, but Beta2's unrounded ratio is larger, so ordering by the
-- unrounded value puts Beta2 first while ordering by the output column (rounded) puts Alpha2 first.
INSERT INTO stores (store_id, store_name, location) VALUES
  (13, 'Mid',    'C'),
  (11, 'Alpha',  'B'),
  (15, 'Beta2',  'E'),
  (10, 'Zeta',   'A'),
  (14, 'Alpha2', 'D');

INSERT INTO inventory (inventory_id, store_id, product_name, quantity, price) VALUES
  (1,  10, 'z1', 1,   90.00),
  (2,  10, 'z2', 5,   50.00),
  (3,  10, 'z3', 3,   10.00),
  (4,  11, 'a1', 2,   90.00),
  (5,  11, 'a2', 9,   50.00),
  (6,  11, 'a3', 4,   10.00),
  (7,  13, 'm1', 3,   90.00),
  (8,  13, 'm2', 1,   50.00),
  (9,  13, 'm3', 6,   10.00),
  (10, 14, 'p',  3,   90.00),
  (11, 14, 'q',  1,   50.00),
  (12, 14, 'r',  5,   10.00),
  (13, 15, 'p',  100, 90.00),
  (14, 15, 'q',  1,   50.00),
  (15, 15, 'r',  167, 10.00);

-- expect: 10,Zeta,A,z1,z3,3.00 | ratio 3/1 = 3, the largest, so first although 'Zeta' sorts last
-- expect: 11,Alpha,B,a1,a3,2.00 | ratio 4/2 = 2; ties with Mid, 'Alpha' < 'Mid'
-- expect: 13,Mid,C,m1,m3,2.00 | ratio 6/3 = 2; same ratio as Alpha, so store_name decides
-- expect: 14,Alpha2,D,p,r,1.67 | 5/3 = 1.6667 rounds to 1.67; ties on the ROUNDED ratio with Beta2, 'Alpha2' < 'Beta2'
-- expect: 15,Beta2,E,p,r,1.67 | 167/100 = 1.6700; after Alpha2 even though its unrounded ratio is higher
