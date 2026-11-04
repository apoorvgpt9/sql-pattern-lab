-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (product_id, year, quantity, price) is covering (no other Sales column is read) and ordered by
-- product then year:
--   01: each correlated MIN(year) is one read at the start of that product's index range;
--   02: PARTITION BY product_id streams in index order, with no sort;
--   03: GROUP BY product_id / MIN(year) can be answered from the index without a temporary table.
CREATE INDEX idx_sales_product_year ON Sales (product_id, year, quantity, price);
