-- Duplicate purchase rows. Customer 1 has three rows, all the same product; customer 2 has three rows covering two products.
-- Both have as many ROWS as there are products (3), which fools COUNT(*) = total.
INSERT INTO Product (product_key) VALUES (1), (2), (3);

INSERT INTO Customer (customer_id, product_key) VALUES
  (1, 1), (1, 1), (1, 1),
  (2, 1), (2, 2), (2, 2),
  (3, 1), (3, 2), (3, 3);

-- expect: 3 | the only customer with three DISTINCT products (customers 1 and 2 have 3 rows but only 1 and 2 products)
