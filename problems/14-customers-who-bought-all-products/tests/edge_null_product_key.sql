-- A NULL product_key is not a product (README Assumptions). Customer 1 has rows (1, 2, NULL): three rows and three
-- distinct values if NULL is counted, but only two real products.
INSERT INTO Product (product_key) VALUES (1), (2), (3);

INSERT INTO Customer (customer_id, product_key) VALUES
  (1, 1), (1, 2), (1, NULL),
  (2, 1), (2, 2), (2, 3), (2, NULL);

-- expect: 2 | bought products 1, 2 and 3 (the NULL row is ignored)
-- (customer 1: only products 1 and 2 are real; the NULL row must not make up the third)
