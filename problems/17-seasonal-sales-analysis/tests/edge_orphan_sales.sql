-- Sales whose product is not in products. Their category is unknown, so they cannot belong to any
-- (season, category) group. A season whose only sales are orphans has no row.
INSERT INTO products (product_id, product_name, category) VALUES
  (1, 'p1', 'Real');

INSERT INTO sales (sale_id, product_id, sale_date, quantity, price) VALUES
  (1, 1,  '2023-07-01', 1,   1.00),  -- Summer, Real: 1 unit, 1.00
  (2, 99, '2023-07-02', 500, 9.00),  -- Summer, unknown product: would win Summer if it counted
  (3, 99, '2023-01-02', 5,   1.00);  -- Winter, unknown product only: Winter must not appear

-- expect: Summer,Real,1,1.00 | the 500-unit sale of product 99 has no category and is ignored
-- (no Winter row: its only sale belongs to an unknown product)
