-- Four customers. Customer 1: first order scheduled, a later order immediate (ignored). Customer 3: the order
-- with the smaller delivery_id (4) is NOT the earliest one - the earliest (id 5, 08-21) is immediate.
INSERT INTO Delivery (delivery_id, customer_id, order_date, customer_pref_delivery_date) VALUES
  (1, 1, '2019-08-01', '2019-08-02'),
  (2, 2, '2019-08-02', '2019-08-02'),
  (3, 1, '2019-08-11', '2019-08-11'),
  (4, 3, '2019-08-24', '2019-08-26'),
  (5, 3, '2019-08-21', '2019-08-21'),
  (6, 4, '2019-08-09', '2019-08-09');

-- expect: 75.00 | first orders: c1 = delivery 1 (scheduled), c2 = delivery 2 (immediate), c3 = delivery 5 (08-21, immediate), c4 = delivery 6 (immediate): 3 of 4 = 75.00
