-- Product has a single row, so "all products" means "that one product". A hard-coded product count would fail here.
INSERT INTO Product (product_key) VALUES (7);

INSERT INTO Customer (customer_id, product_key) VALUES
  (1, 7), (1, 7),
  (2, 7),
  (5, 7);

-- expect: 1 | bought the only product (twice; listed once)
-- expect: 2 | bought the only product
-- expect: 5 | bought the only product; ids need not be consecutive
