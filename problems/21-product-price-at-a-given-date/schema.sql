-- Product Price at a Given Date (LeetCode 1164): tables for MySQL 8.0. Names mirror the original.
-- One table of price CHANGES (not a product master): a product with no change on or before the
-- target date has no row that tells you its price, which is why the answer needs a default.

CREATE TABLE Products (
  product_id  INT NOT NULL,
  new_price   INT NOT NULL,
  change_date DATE NOT NULL,
  PRIMARY KEY (product_id, change_date)   -- grain: one row per price change
);
