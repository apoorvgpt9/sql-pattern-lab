-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (store_id, amount, order_id) is the window's own PARTITION BY + ORDER BY, and covering
-- (the InnoDB secondary index carries order_id anyway; listing it makes the order explicit):
--   01: each correlated count becomes a range read inside one store instead of a full table scan;
--   02/03: the rows can be read already grouped by store and sorted by (amount, order_id).
CREATE INDEX idx_storeorders_store_amount ON StoreOrders (store_id, amount, order_id);
