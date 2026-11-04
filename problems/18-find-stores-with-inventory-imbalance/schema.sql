-- Find Stores with Inventory Imbalance (LeetCode 3626): tables for MySQL 8.0. Names mirror the original.
-- Assumptions made explicit here (README "Assumptions"):
--   * a store lists each product at most once (UNIQUE (store_id, product_name)): the grain says
--     "one row per product stocked at a store", and the spec counts "different products" as rows;
--   * quantity > 0 (a store does not keep a zero-stock row), so the ratio never divides by zero.

CREATE TABLE stores (
  store_id   INT PRIMARY KEY,       -- grain: one row per store
  store_name VARCHAR(100),
  location   VARCHAR(100)
);

CREATE TABLE inventory (
  inventory_id INT PRIMARY KEY,     -- grain: one row per product stocked at a store
  store_id     INT NOT NULL,
  product_name VARCHAR(100) NOT NULL,
  quantity     INT NOT NULL CHECK (quantity > 0),
  price        DECIMAL(10,2) NOT NULL,
  UNIQUE (store_id, product_name)
);
