-- The cut-off: a pair needs AT LEAST 3 customers. One pair has exactly 3, another exactly 2.
INSERT INTO ProductInfo (product_id, category, price) VALUES
  (1, 'Books', 10.00), (2, 'Books', 11.00), (3, 'Toys', 5.00), (4, 'Games', 7.50);

INSERT INTO ProductPurchases (user_id, product_id, quantity) VALUES
  (1, 1, 1), (1, 2, 1),
  (2, 1, 1), (2, 2, 1),
  (3, 1, 1), (3, 2, 1),   -- products 1 and 2: three customers
  (4, 3, 1), (4, 4, 1),
  (5, 3, 1), (5, 4, 1);   -- products 3 and 4: only two customers

-- expect: 1,2,Books,Books,3 | exactly three customers is enough (>= 3), and two products may share a category
-- (pair 3,4 has exactly 2 customers: just below the minimum)
