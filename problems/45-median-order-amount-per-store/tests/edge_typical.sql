-- Typical: an odd store (5 orders), an even store (4 orders), a one-order store. Rows are inserted
-- in no particular order and order_ids interleave across stores.
INSERT INTO StoreOrders (order_id, store_id, amount) VALUES
  (1, 1, 12.00),
  (2, 2, 10.00),
  (3, 1,  3.50),
  (4, 3, 99.99),
  (5, 2, 40.00),
  (6, 1,  7.25),
  (7, 2, 25.50),
  (8, 1, 20.00),
  (9, 2, 30.00),
  (10, 1, 7.00);

-- expect: 1,7.25 | n=5 sorted 3.50, 7.00, 7.25, 12.00, 20.00; middle position (5+1) DIV 2 = 3 -> 7.25 (the mean would be 49.75/5 = 9.95)
-- expect: 2,27.75 | n=4 sorted 10.00, 25.50, 30.00, 40.00; positions 2 and 3 -> (25.50 + 30.00)/2 = 55.50/2 = 27.750000 -> ROUND 27.75
-- expect: 3,99.99 | n=1: the only order is the median
