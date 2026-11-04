-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- Customer has no primary key, so without an index it is a heap that every approach must scan or probe.
-- (customer_id, product_key) is covering: approach 3 can count distinct products per customer in index order without a
-- temporary table, approach 1's inner probe "does (customer, product) exist?" becomes a point lookup, and approach 2's
-- bought/grid join becomes an index join.
CREATE INDEX idx_customer_cust_prod ON Customer (customer_id, product_key);
