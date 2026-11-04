-- The cut-off: at least 3 customers. (Books, Toys) has exactly 3, (Electronics, Toys) exactly 2.
INSERT INTO ProductInfo (product_id, category, price) VALUES
  (1, 'Books', 10.00), (3, 'Electronics', 99.00), (5, 'Toys', 20.00);

INSERT INTO ProductPurchases (user_id, product_id, quantity) VALUES
  (1, 1, 1), (1, 5, 1),
  (2, 1, 1), (2, 5, 1),
  (3, 1, 1), (3, 5, 1),   -- customers 1-3: Books and Toys
  (4, 3, 1), (4, 5, 1),
  (5, 3, 1), (5, 5, 1);   -- customers 4-5: Electronics and Toys

-- expect: Books,Toys,3 | exactly three customers is enough (>= 3)
-- (Electronics,Toys has exactly 2 customers: just below the minimum)
