-- Two qualifying customers and three that each fail one criterion.
INSERT INTO restaurant_orders (order_id, customer_id, order_timestamp, order_amount, payment_method, order_rating) VALUES
  (1,  1, '2024-03-01 12:00:00', 20.00, 'card', 5),
  (2,  1, '2024-03-02 19:00:00', 20.00, 'card', 4),
  (3,  1, '2024-03-03 13:00:00', 20.00, 'app',  NULL),
  (4,  2, '2024-03-01 12:00:00', 20.00, 'cash', 4),
  (5,  2, '2024-03-02 19:00:00', 20.00, 'cash', 4),
  (6,  2, '2024-03-03 08:00:00', 20.00, 'cash', 4),
  (7,  3, '2024-03-01 12:00:00', 20.00, 'card', 5),
  (8,  3, '2024-03-02 19:00:00', 20.00, 'card', 5),
  (9,  4, '2024-03-01 08:00:00', 20.00, 'app',  5),
  (10, 4, '2024-03-02 15:00:00', 20.00, 'app',  5),
  (11, 4, '2024-03-03 12:00:00', 20.00, 'app',  5),
  (12, 5, '2024-03-01 12:00:00', 20.00, 'cash', 3),
  (13, 5, '2024-03-02 12:00:00', 20.00, 'cash', 3),
  (14, 5, '2024-03-03 12:00:00', 20.00, 'cash', 5);

-- expect: 1,3,100,4.50 | 3 orders, all in peak windows (12:00, 19:00, 13:00) = 100%; ratings 5 and 4 (the NULL is skipped): avg 4.50; 2 of 3 rated = 67% >= 50%
-- expect: 2,3,67,4.00 | 2 of 3 orders peak = 66.67% -> 67; all rated; avg exactly 4.00 qualifies (>= 4.0)
--   customer 3: only 2 orders -> out. customer 4: 1 of 3 peak = 33% -> out. customer 5: avg (3+3+5)/3 = 3.67 -> out
