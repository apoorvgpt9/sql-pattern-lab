-- Ordering test (store_id ASC): stores inserted in descending id order, ids not contiguous, and the
-- medians fall as store_id rises, so neither insertion order nor median order is the answer.
INSERT INTO StoreOrders (order_id, store_id, amount) VALUES
  (1, 100, 1.00),
  (2,  42, 4.00),
  (3,  42, 2.00),
  (4,   7, 70.00),
  (5,   7, 50.00),
  (6,   7, 60.00);

-- expect: 7,60.00 | n=3 sorted 50.00, 60.00, 70.00 -> position 2 = 60.00; smallest store_id first
-- expect: 42,3.00 | n=2: (2.00 + 4.00)/2 = 6.00/2 = 3.000000 -> 3.00
-- expect: 100,1.00 | n=1 -> 1.00; largest store_id last
