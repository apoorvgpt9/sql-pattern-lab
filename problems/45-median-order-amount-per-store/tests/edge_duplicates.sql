-- Duplicate amounts. Positions must come from ROW_NUMBER over (amount, order_id): RANK leaves gaps
-- (1, 1, 1, 4) so the middle positions may not exist, and DENSE_RANK compresses them (1, 1, 1, 2).
INSERT INTO StoreOrders (order_id, store_id, amount) VALUES
  (1, 10, 5.00),
  (2, 10, 5.00),
  (3, 10, 9.00),
  (4, 10, 5.00),
  (5, 20, 2.00),
  (6, 20, 8.00),
  (7, 20, 2.00),
  (8, 30, 4.00),
  (9, 30, 4.00);

-- expect: 10,5.00 | n=4 sorted 5.00 (o1), 5.00 (o2), 5.00 (o4), 9.00 (o3); positions 2, 3 -> (5.00 + 5.00)/2 = 5.000000 -> 5.00
-- expect: 20,2.00 | n=3 sorted 2.00 (o5), 2.00 (o7), 8.00 (o6); position 2 -> 2.00
-- expect: 30,4.00 | n=2, both 4.00; positions 1, 2 -> (4.00 + 4.00)/2 = 4.00
