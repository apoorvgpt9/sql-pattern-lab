-- No customer's first order is immediate: 0.00, not NULL. Customer 2 has an immediate LATER order,
-- which must not count.
INSERT INTO Delivery (delivery_id, customer_id, order_date, customer_pref_delivery_date) VALUES
  (1, 1, '2022-06-01', '2022-06-02'),
  (2, 2, '2022-06-01', '2022-06-05'),
  (3, 2, '2022-06-10', '2022-06-10');

-- expect: 0.00 | first orders are deliveries 1 and 2, both scheduled: 0 of 2 = 0.00 (a conditional SUM with no ELSE would be NULL)
