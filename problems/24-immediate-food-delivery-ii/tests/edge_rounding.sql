-- 3 of 7 first orders are immediate: 3 / 7 = 42.857142..., rounded to 2 decimals = 42.86.
-- (Rounding the fraction before scaling, ROUND(3/7, 2) * 100 = 43.00, is wrong.) One order per customer.
INSERT INTO Delivery (delivery_id, customer_id, order_date, customer_pref_delivery_date) VALUES
  (1, 1, '2020-01-01', '2020-01-01'),
  (2, 2, '2020-01-02', '2020-01-02'),
  (3, 3, '2020-01-03', '2020-01-03'),
  (4, 4, '2020-01-04', '2020-01-05'),
  (5, 5, '2020-01-05', '2020-01-06'),
  (6, 6, '2020-01-06', '2020-01-08'),
  (7, 7, '2020-01-07', '2020-01-09');

-- expect: 42.86 | 3 immediate of 7 customers: 3 / 7 = 0.428571... -> 42.857142... -> 42.86
