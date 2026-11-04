-- Stores exist, inventory is empty.
INSERT INTO stores (store_id, store_name, location) VALUES
  (1, 'Alpha', 'X'), (2, 'Beta', 'Y');

-- expect-empty: no inventory rows, so no store stocks 3 products
