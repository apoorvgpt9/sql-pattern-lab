-- Typical: three products. Customer 1 bought everything (and product 1 twice, so it has 4 rows), customer 2 is
-- missing product 3, customer 3 bought everything in a different order, customer 4 bought one product.
INSERT INTO Product (product_key) VALUES (1), (2), (3);

INSERT INTO Customer (customer_id, product_key) VALUES
  (1, 1), (1, 2), (1, 3), (1, 1),
  (2, 1), (2, 2),
  (3, 3), (3, 2), (3, 1),
  (4, 3);

-- expect: 1 | has products 1, 2 and 3 (4 rows, 3 distinct products)
-- expect: 3 | has products 3, 2 and 1
-- (customer 2 lacks product 3; customer 4 has only product 3)
