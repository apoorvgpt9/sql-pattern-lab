-- Product 7 is purchased but has no ProductInfo row (no foreign key). The pair still qualifies (3 customers),
-- so it is reported with a NULL category (README Assumptions). An inner join to ProductInfo loses it.
INSERT INTO ProductInfo (product_id, category, price) VALUES (1, 'Books', 10.00);

INSERT INTO ProductPurchases (user_id, product_id, quantity) VALUES
  (1, 1, 1), (1, 7, 1),
  (2, 1, 1), (2, 7, 1),
  (3, 1, 1), (3, 7, 1);

-- expect: 1,7,Books,NULL,3 | three customers bought 1 and 7; product 7 has no category, so NULL
