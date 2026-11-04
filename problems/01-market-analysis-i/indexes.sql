-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (buyer_id, order_date) is covering for all three solutions:
--   01: each correlated subquery becomes an index range read of one buyer's entries;
--   02: the join can probe the index instead of building a hash table;
--   03: the GROUP BY can stream in buyer_id order instead of using a temporary table.
CREATE INDEX idx_orders_buyer_date ON Orders (buyer_id, order_date);
