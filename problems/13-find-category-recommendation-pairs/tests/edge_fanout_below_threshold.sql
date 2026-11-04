-- Two customers, each with two products in each of two categories. The product-level join produces
-- 2 x 2 = 4 rows per customer, 8 in total: enough to pass "at least 3" if you count rows. Only 2 customers exist.
INSERT INTO ProductInfo (product_id, category, price) VALUES
  (1, 'Books', 10.00), (2, 'Books', 12.00), (3, 'Electronics', 99.00), (4, 'Electronics', 45.00);

INSERT INTO ProductPurchases (user_id, product_id, quantity) VALUES
  (1, 1, 1), (1, 2, 1), (1, 3, 1), (1, 4, 1),
  (2, 1, 1), (2, 2, 1), (2, 3, 1), (2, 4, 1);

-- expect-empty: only 2 distinct customers bought from both categories, however many product-level rows they generate
