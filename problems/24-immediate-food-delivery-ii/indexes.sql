-- Index discussed in README "At scale" (b). The bench runs every solution without it, then with it.
-- The primary key is delivery_id, which says nothing about customers or dates. This covering index orders rows by
-- (customer_id, order_date) and holds the preferred date. What the bench's EXPLAIN ANALYZE showed at 1M rows:
--   01: each correlated MIN(order_date) is a covering lookup of the customer's whole range; 01 now finishes;
--   02: GROUP BY customer_id / MIN(order_date) becomes a skip scan, and the join back an index lookup per customer;
--       this makes 02 the fastest approach with the index;
--   03: no change. MySQL still sorts, and its main cost is materialising the 1M-row CTE, not the sort.
CREATE INDEX idx_delivery_customer_date ON Delivery (customer_id, order_date, customer_pref_delivery_date);
