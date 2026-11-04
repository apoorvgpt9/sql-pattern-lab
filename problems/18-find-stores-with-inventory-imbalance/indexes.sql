-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- schema.sql already has UNIQUE (store_id, product_name), so every store's rows can be found by
-- store_id without a table scan. This index makes that lookup COVERING: price, quantity and
-- product_name are all inside the index entry, so no approach needs to visit the base table, and the
-- rows of one store arrive already ordered by price (the "highest" direction of the rankings and the
-- "lowest" direction both start from this order).
CREATE INDEX idx_inventory_store_price ON inventory (store_id, price, quantity, product_name);
