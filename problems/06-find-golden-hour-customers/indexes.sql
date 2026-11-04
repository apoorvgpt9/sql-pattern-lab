-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (customer_id, order_timestamp, order_rating) is covering for all three solutions (no other column is read):
--   01: each per-customer subquery becomes an index range read of that customer's entries;
--   02, 03: GROUP BY customer_id arrives in index order, so aggregation streams without a temporary table,
--           and the table rows are never touched.
-- The time-of-day test TIME(order_timestamp) is evaluated per entry: no index can skip rows because of it.
CREATE INDEX idx_orders_customer_ts_rating ON restaurant_orders (customer_id, order_timestamp, order_rating);
