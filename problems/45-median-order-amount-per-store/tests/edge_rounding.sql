-- Even stores whose midpoint has a third decimal of 5. MySQL computes AVG over DECIMAL(10,2) exactly
-- (result scale 2 + 4 = 6) and ROUND on an exact DECIMAL rounds half away from zero.
INSERT INTO StoreOrders (order_id, store_id, amount) VALUES
  (1, 1, 10.25),
  (2, 1, 10.00),
  (3, 2,  0.02),
  (4, 2,  0.01),
  (5, 3,  1.10),
  (6, 3,  1.30),
  (7, 3,  1.20),
  (8, 3,  1.15);

-- expect: 1,10.13 | n=2: (10.00 + 10.25)/2 = 20.25/2 = 10.125000 -> ROUND(10.125000, 2) = 10.13 (half away from zero)
-- expect: 2,0.02 | n=2: (0.01 + 0.02)/2 = 0.03/2 = 0.015000 -> 0.02
-- expect: 3,1.18 | n=4 sorted 1.10, 1.15, 1.20, 1.30; positions 2, 3 -> (1.15 + 1.20)/2 = 2.35/2 = 1.175000 -> 1.18
