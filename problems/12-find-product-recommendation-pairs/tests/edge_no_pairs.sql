-- Every customer bought exactly one product: there is nothing to pair, so no rows.
INSERT INTO ProductInfo (product_id, category, price) VALUES (1, 'Books', 10.00), (2, 'Toys', 5.00);

INSERT INTO ProductPurchases (user_id, product_id, quantity) VALUES
  (1, 1, 1), (2, 1, 1), (3, 1, 1), (4, 2, 1), (5, 2, 1);

-- expect-empty: no customer bought two different products; a join without the same-customer condition would still invent pairs
