-- Index discussed in README "At scale" (b). The bench runs every solution without it, then with it.
-- (product_id, year, quantity, price) is covering (no other Sales column is read) and ordered by product then year.
-- What the bench's EXPLAIN ANALYZE showed at 1M rows:
--   01: each correlated MIN(year) is a covering lookup of the product's whole range (not one entry); 01 now finishes;
--   02: no benefit. MySQL still sorts, and the cost is the buffered window, not the sort;
--   03: GROUP BY product_id / MIN(year) becomes a skip scan (one entry per product) and the join back an index lookup.
CREATE INDEX idx_sales_product_year ON Sales (product_id, year, quantity, price);
