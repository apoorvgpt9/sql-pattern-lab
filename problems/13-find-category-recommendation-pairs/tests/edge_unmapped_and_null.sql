-- A purchase of a product with no ProductInfo row (product 9), and a product whose category is NULL (product 8).
-- Neither belongs to any category (README Assumptions), so neither can form a pair, even though all three customers bought them.
INSERT INTO ProductInfo (product_id, category, price) VALUES
  (1, 'Books', 10.00), (2, 'Toys', 20.00), (8, NULL, 5.00);

INSERT INTO ProductPurchases (user_id, product_id, quantity) VALUES
  (1, 1, 1), (1, 2, 1), (1, 8, 1), (1, 9, 1),
  (2, 1, 1), (2, 2, 1), (2, 8, 1), (2, 9, 1),
  (3, 1, 1), (3, 2, 1), (3, 8, 1), (3, 9, 1);

-- expect: Books,Toys,3 | the three customers bought both; products 8 (NULL category) and 9 (unknown product) form no category and therefore no pair
