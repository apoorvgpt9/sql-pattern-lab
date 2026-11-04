-- Typical: three products, five customers. Two pairs reach 3 customers, one pair has only 2.
-- User 3's purchase of product 2 has quantity 0: quantity is irrelevant, the row still means "bought".
INSERT INTO ProductInfo (product_id, category, price) VALUES
  (1, 'Electronics', 99.99), (2, 'Books', 12.50), (3, 'Toys', 20.00);

INSERT INTO ProductPurchases (user_id, product_id, quantity) VALUES
  (1, 1, 1), (1, 2, 2), (1, 3, 1),   -- user 1 bought 1, 2, 3
  (2, 1, 3), (2, 2, 1), (2, 3, 5),   -- user 2 bought 1, 2, 3
  (3, 1, 1), (3, 2, 0),              -- user 3 bought 1 and 2 (quantity 0 on product 2)
  (4, 1, 2), (4, 3, 1),              -- user 4 bought 1 and 3
  (5, 2, 4);                         -- user 5 bought only product 2: no pair

-- expect: 1,2,Electronics,Books,3 | users 1, 2, 3 bought both 1 and 2 (user 3's quantity 0 still counts)
-- expect: 1,3,Electronics,Toys,3 | users 1, 2, 4 bought both 1 and 3
-- (pair 2,3 has only users 1 and 2, below the minimum of 3; no row for mirrored (2,1) or (3,1); no row for a product paired with itself)
