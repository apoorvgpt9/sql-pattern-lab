-- Typical. Customer 1 bought TWO Books products and one Electronics product: at product grain that is two
-- (Books, Electronics) rows, but it is one customer. Customer 6 bought two products of one category only.
INSERT INTO ProductInfo (product_id, category, price) VALUES
  (1, 'Books', 10.00), (2, 'Books', 12.00), (3, 'Electronics', 99.00), (4, 'Electronics', 45.00), (5, 'Toys', 20.00);

INSERT INTO ProductPurchases (user_id, product_id, quantity) VALUES
  (1, 1, 1), (1, 2, 1), (1, 3, 1),   -- customer 1: Books x2, Electronics
  (2, 1, 1), (2, 3, 2),              -- customer 2: Books, Electronics
  (3, 2, 1), (3, 4, 1),              -- customer 3: Books, Electronics (different products from customer 1)
  (4, 1, 1), (4, 5, 1),              -- customer 4: Books, Toys
  (5, 3, 1), (5, 5, 3),              -- customer 5: Electronics, Toys
  (6, 1, 1), (6, 2, 1);              -- customer 6: Books only

-- expect: Books,Electronics,3 | customers 1, 2, 3 each bought from both categories; customer 1 counts once although the product-level join gives 2 rows (a COUNT(*) there would say 4)
-- (Books/Toys has only customer 4 and Electronics/Toys only customer 5; customer 6 has a single category; no (Books, Books) row)
