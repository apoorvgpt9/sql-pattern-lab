-- Everybody is missing at least one product, though some have many purchases.
INSERT INTO Product (product_key) VALUES (1), (2), (3);

INSERT INTO Customer (customer_id, product_key) VALUES
  (1, 1), (1, 2), (1, 2), (1, 1),
  (2, 2), (2, 3),
  (3, 1), (3, 3);

-- expect-empty: customer 1 lacks product 3, customer 2 lacks product 1, customer 3 lacks product 2
