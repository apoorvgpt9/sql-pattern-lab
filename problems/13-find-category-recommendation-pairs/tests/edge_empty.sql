-- No purchases at all.
INSERT INTO ProductInfo (product_id, category, price) VALUES (1, 'Books', 10.00), (2, 'Toys', 5.00);

-- expect-empty: no purchases, so no category pairs
