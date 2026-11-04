-- Customers Who Bought All Products (LeetCode 1045): tables for MySQL 8.0. Names mirror the original.
-- Customer has no primary key: purchase rows may repeat exactly (spec). product_key is nullable only to test that a
-- NULL is not a product (README Assumptions). No FOREIGN KEY constraint, as on LeetCode: the spec promises that every
-- non-NULL product_key in Customer exists in Product, and the datasets and gen.py keep that promise.

CREATE TABLE Customer (
  customer_id INT NOT NULL,
  product_key INT              -- references Product(product_key)
);

CREATE TABLE Product (
  product_key INT PRIMARY KEY  -- grain: one row per product
);
