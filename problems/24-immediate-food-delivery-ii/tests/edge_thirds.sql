-- 1 of 3: 33.33 (repeating decimals). Customer 1 has three orders, customers 2 and 3 one each.
INSERT INTO Delivery (delivery_id, customer_id, order_date, customer_pref_delivery_date) VALUES
  (1, 1, '2021-03-01', '2021-03-01'),
  (2, 1, '2021-03-02', '2021-03-03'),
  (3, 1, '2021-03-02', '2021-03-04'),
  (4, 2, '2021-03-05', '2021-03-06'),
  (5, 3, '2021-03-05', '2021-03-09');

-- expect: 33.33 | first orders: c1 = delivery 1 (immediate), c2 = delivery 4 and c3 = delivery 5 (scheduled); 1 / 3 = 33.33 (c1's later orders, two sharing a date, do not matter)
