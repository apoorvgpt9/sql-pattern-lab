-- Peak windows are inclusive at both ends: 11:00:00-14:00:00 and 18:00:00-21:00:00. One second outside is not peak.
-- Customer 1 sits on the four boundary instants. Customer 2 sits one second outside each window (plus one real peak order).
-- A shortcut on HOUR() alone would treat 14:00:01 and 21:00:01 as peak (hour 14 and 21), and drop the boundary instants.
INSERT INTO restaurant_orders (order_id, customer_id, order_timestamp, order_amount, payment_method, order_rating) VALUES
  (1,  1, '2024-04-01 11:00:00', 10.00, 'card', 5),
  (2,  1, '2024-04-02 14:00:00', 10.00, 'card', 5),
  (3,  1, '2024-04-03 18:00:00', 10.00, 'card', 5),
  (4,  1, '2024-04-04 21:00:00', 10.00, 'card', 5),
  (5,  1, '2024-04-05 22:00:00', 10.00, 'card', 5),
  (6,  2, '2024-04-01 10:59:59', 10.00, 'app',  5),
  (7,  2, '2024-04-02 14:00:01', 10.00, 'app',  5),
  (8,  2, '2024-04-03 17:59:59', 10.00, 'app',  5),
  (9,  2, '2024-04-04 21:00:01', 10.00, 'app',  5),
  (10, 2, '2024-04-05 12:00:00', 10.00, 'app',  5);

-- expect: 1,5,80,5.00 | peak = 11:00:00, 14:00:00, 18:00:00, 21:00:00 (all inclusive) = 4 of 5 = 80%; 22:00 is not peak
--   customer 2: only the 12:00:00 order is peak (10:59:59, 14:00:01, 17:59:59, 21:00:01 are one second outside): 1 of 5 = 20% -> out
