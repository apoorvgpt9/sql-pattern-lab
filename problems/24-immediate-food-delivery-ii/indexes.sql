-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- The primary key is delivery_id, which says nothing about customers or dates, so every approach has to
-- group or sort the whole table by customer. This covering index delivers rows already ordered by
-- (customer_id, order_date) and holds the preferred date, so:
--   01: each correlated MIN(order_date) is one read at the start of a customer's range;
--   02: GROUP BY customer_id / MIN(order_date) streams in index order;
--   03: PARTITION BY customer_id ORDER BY order_date matches the index, so no sort is needed.
CREATE INDEX idx_delivery_customer_date ON Delivery (customer_id, order_date, customer_pref_delivery_date);
