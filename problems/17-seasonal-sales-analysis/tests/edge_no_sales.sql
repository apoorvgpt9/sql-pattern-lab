-- products exist, sales is empty.
INSERT INTO products (product_id, product_name, category) VALUES
  (1, 'p1', 'Books'), (2, 'p2', 'Toys');

-- expect-empty: no sales, so no season has a best category
