-- Every first order is immediate: 100.00.
INSERT INTO Delivery (delivery_id, customer_id, order_date, customer_pref_delivery_date) VALUES
  (1, 1, '2022-06-01', '2022-06-01'),
  (2, 2, '2022-06-02', '2022-06-02'),
  (3, 2, '2022-06-09', '2022-06-12');

-- expect: 100.00 | first orders are deliveries 1 and 2, both immediate: 2 of 2 = 100.00 (customer 2's later scheduled order is ignored)
