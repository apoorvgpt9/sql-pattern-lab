-- Every threshold is inclusive and each of customers 1-3 sits exactly on one of them:
-- 3 orders; 60% peak; 50% rated; average rating 4.0. Customer 4 is just below the rated-share threshold.
-- Customers 1 and 2 also tie on average_rating (5.00): the tie breaks by customer_id DESC, so 2 comes before 1.
INSERT INTO restaurant_orders (order_id, customer_id, order_timestamp, order_amount, payment_method, order_rating) VALUES
  (1,  1, '2024-05-01 12:00:00', 10.00, 'card', 5),
  (2,  1, '2024-05-02 12:00:00', 10.00, 'card', 5),
  (3,  1, '2024-05-03 12:00:00', 10.00, 'card', 5),
  (4,  2, '2024-05-01 12:00:00', 10.00, 'card', 5),
  (5,  2, '2024-05-02 12:00:00', 10.00, 'card', 5),
  (6,  2, '2024-05-03 12:00:00', 10.00, 'card', 5),
  (7,  2, '2024-05-04 08:00:00', 10.00, 'card', 5),
  (8,  2, '2024-05-05 08:00:00', 10.00, 'card', 5),
  (9,  3, '2024-05-01 12:00:00', 10.00, 'app',  4),
  (10, 3, '2024-05-02 12:00:00', 10.00, 'app',  4),
  (11, 3, '2024-05-03 12:00:00', 10.00, 'app',  NULL),
  (12, 3, '2024-05-04 12:00:00', 10.00, 'app',  NULL),
  (13, 4, '2024-05-01 12:00:00', 10.00, 'cash', 5),
  (14, 4, '2024-05-02 12:00:00', 10.00, 'cash', NULL),
  (15, 4, '2024-05-03 12:00:00', 10.00, 'cash', NULL);

-- expect: 2,5,60,5.00 | 3 of 5 orders peak = exactly 60% qualifies (>= 60%); all rated, avg 5.00; ties with customer 1 on rating, so customer_id DESC puts it first
-- expect: 1,3,100,5.00 | exactly 3 orders qualifies (>= 3); avg 5.00
-- expect: 3,4,100,4.00 | 2 of 4 rated = exactly 50% qualifies; average over the 2 non-NULL ratings = exactly 4.00 qualifies
--   customer 4: 1 of 3 rated = 33% < 50% -> out, although its one rating is 5
