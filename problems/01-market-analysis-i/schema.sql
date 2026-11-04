-- Market Analysis I (LeetCode 1158): tables for MySQL 8.0. Names mirror the original.
-- No foreign keys, as on LeetCode: orders may reference buyers that are not in Users.

CREATE TABLE Users (
  user_id        INT PRIMARY KEY,   -- grain: one row per user
  join_date      DATE,
  favorite_brand VARCHAR(100)
);

CREATE TABLE Orders (
  order_id   INT PRIMARY KEY,       -- grain: one row per order
  order_date DATE,
  item_id    INT,
  buyer_id   INT,
  seller_id  INT
);

CREATE TABLE Items (
  item_id    INT PRIMARY KEY,       -- grain: one row per item; not needed for the answer
  item_brand VARCHAR(100)
);
