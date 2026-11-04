-- Everyone buys several products, but all in one category: no pair of DIFFERENT categories exists.
INSERT INTO ProductInfo (product_id, category, price) VALUES
  (1, 'Books', 10.00), (2, 'Books', 12.00), (3, 'Books', 15.00);

INSERT INTO ProductPurchases (user_id, product_id, quantity) VALUES
  (1, 1, 1), (1, 2, 1),
  (2, 2, 1), (2, 3, 1),
  (3, 1, 1), (3, 3, 1),
  (4, 1, 1), (4, 2, 1);

-- expect-empty: only one category exists, and a category is never paired with itself (category1 < category2 is strict)
