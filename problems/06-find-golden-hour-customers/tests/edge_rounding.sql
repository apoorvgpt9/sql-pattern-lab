-- Rounding. MySQL divides exact numbers (DECIMAL) and rounds halves away from zero; peak_hour_percentage is rounded to an
-- integer and average_rating to 2 decimals.
INSERT INTO restaurant_orders (order_id, customer_id, order_timestamp, order_amount, payment_method, order_rating) VALUES
  (1,  1, '2024-07-01 12:00:00', 10.00, 'card', 5),
  (2,  1, '2024-07-02 12:30:00', 10.00, 'card', 4),
  (3,  1, '2024-07-03 13:00:00', 10.00, 'card', 4),
  (4,  1, '2024-07-04 18:30:00', 10.00, 'card', 4),
  (5,  1, '2024-07-05 19:00:00', 10.00, 'card', 4),
  (6,  1, '2024-07-06 08:00:00', 10.00, 'card', 4),
  (7,  1, '2024-07-07 15:00:00', 10.00, 'card', 4),
  (8,  1, '2024-07-08 22:00:00', 10.00, 'card', 4),
  (9,  2, '2024-07-01 11:00:00', 10.00, 'app',  5),
  (10, 2, '2024-07-02 12:00:00', 10.00, 'app',  5),
  (11, 2, '2024-07-03 19:00:00', 10.00, 'app',  4),
  (12, 2, '2024-07-04 20:00:00', 10.00, 'app',  4),
  (13, 2, '2024-07-05 09:00:00', 10.00, 'app',  4),
  (14, 2, '2024-07-06 16:00:00', 10.00, 'app',  4);

-- expect: 2,6,67,4.33 | 4 of 6 peak = 66.666...% -> 67; ratings sum 26 over 6 = 4.3333 -> 4.33
-- expect: 1,8,63,4.13 | 5 of 8 peak = 62.5% -> rounds half up to 63; ratings sum 33 over 8 = 4.1250 exactly -> ROUND(4.125, 2) = 4.13 (a binary double would give 4.12)
--   order: average_rating DESC puts 4.33 before 4.13
