-- Seasonal Sales Analysis (LeetCode 3564): tables for MySQL 8.0. Names mirror the original.
-- No foreign key, as on LeetCode: a sale may reference a product_id that is not in products.
-- Spec says nulls are n/a, so every column the query reads is NOT NULL.

CREATE TABLE sales (
  sale_id    INT PRIMARY KEY,         -- grain: one row per sale
  product_id INT NOT NULL,
  sale_date  DATE NOT NULL,
  quantity   INT NOT NULL,
  price      DECIMAL(10,2) NOT NULL   -- per unit
);

CREATE TABLE products (
  product_id   INT PRIMARY KEY,       -- grain: one row per product
  product_name VARCHAR(100),
  category     VARCHAR(100) NOT NULL
);
