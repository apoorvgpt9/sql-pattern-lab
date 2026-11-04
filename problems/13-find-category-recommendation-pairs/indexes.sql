-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- The mapping step joins every purchase to ProductInfo on product_id (its primary key, already indexed).
-- Adding category to a covering index on ProductInfo lets that lookup be answered from the index without touching the row,
-- which matters because approach 1 repeats the lookup on every exploded row.
CREATE INDEX idx_productinfo_cover ON ProductInfo (product_id, category);
