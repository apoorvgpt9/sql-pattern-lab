-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- The primary key (user_id, product_id) already serves the self-join: all of one customer's products are adjacent.
-- (product_id, user_id) serves the other direction: it lets "customers per product" (approach 3's popularity prune)
-- and approach 1's "customers who bought product P" be answered from the index alone, without touching the table.
CREATE INDEX idx_pp_product_user ON ProductPurchases (product_id, user_id);
