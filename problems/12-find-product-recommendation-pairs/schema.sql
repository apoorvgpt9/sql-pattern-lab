-- Find Product Recommendation Pairs (LeetCode 3521): tables for MySQL 8.0. Names mirror the original.
-- No foreign key, as on LeetCode: a purchase may name a product that has no ProductInfo row (see README Assumptions).

CREATE TABLE ProductPurchases (
  user_id    INT NOT NULL,
  product_id INT NOT NULL,
  quantity   INT NOT NULL,
  PRIMARY KEY (user_id, product_id)   -- grain: one row per (customer, product)
);

CREATE TABLE ProductInfo (
  product_id INT PRIMARY KEY,         -- grain: one row per product
  category   VARCHAR(100),
  price      DECIMAL(10,2)
);
