-- Product Sales Analysis III (LeetCode 1070): tables for MySQL 8.0. Names mirror the original.
-- The key is (sale_id, year), as on LeetCode: the same sale_id may appear in different years,
-- and a product may have several rows in the same year. `year` is a non-reserved keyword in MySQL.

CREATE TABLE Sales (
  sale_id    INT NOT NULL,
  product_id INT NOT NULL,
  year       INT NOT NULL,
  quantity   INT NOT NULL,
  price      INT NOT NULL,        -- per unit
  PRIMARY KEY (sale_id, year)     -- grain: one row per sale entry
);
