-- NULL ratings count toward total_orders and toward the rated-share test, but are excluded from the average.
INSERT INTO restaurant_orders (order_id, customer_id, order_timestamp, order_amount, payment_method, order_rating) VALUES
  (1,  1, '2024-06-01 12:00:00', 10.00, 'card', 5),
  (2,  1, '2024-06-02 12:00:00', 10.00, 'card', 5),
  (3,  1, '2024-06-03 12:00:00', 10.00, 'card', NULL),
  (4,  1, '2024-06-04 12:00:00', 10.00, 'card', NULL),
  (5,  2, '2024-06-01 12:00:00', 10.00, 'app',  NULL),
  (6,  2, '2024-06-02 12:00:00', 10.00, 'app',  NULL),
  (7,  2, '2024-06-03 12:00:00', 10.00, 'app',  NULL),
  (8,  3, '2024-06-01 12:00:00', 10.00, 'cash', 4),
  (9,  3, '2024-06-02 12:00:00', 10.00, 'cash', 4),
  (10, 3, '2024-06-03 12:00:00', 10.00, 'cash', 4),
  (11, 3, '2024-06-04 08:00:00', 10.00, 'cash', NULL),
  (12, 3, '2024-06-05 08:00:00', 10.00, 'cash', NULL);

-- expect: 1,4,100,5.00 | total_orders counts all 4 orders (NULL ratings included); average over the 2 ratings = 5.00, not (5+5+0+0)/4; 2 of 4 rated = 50%
-- expect: 3,5,60,4.00 | 3 of 5 peak = 60%; 3 of 5 rated = 60%; average of 4,4,4 = 4.00
--   customer 2: three orders, none rated: 0% rated -> out (its average is NULL, and NULL >= 4 is not true)
