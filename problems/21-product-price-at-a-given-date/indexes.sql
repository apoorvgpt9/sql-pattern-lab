-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- The table's primary key (product_id, change_date) already orders each product's changes by date.
-- This index adds new_price so that every approach is answered from the index alone (covering):
--   01: the correlated "latest change on or before the date" is a backward index probe with LIMIT 1;
--   02: the per-product MAX(change_date) with a range filter reads index entries only;
--   03: the window and group by product_id read in index order.
CREATE INDEX idx_products_covering ON Products (product_id, change_date, new_price);
