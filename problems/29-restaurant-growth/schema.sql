-- Restaurant Growth (LeetCode 1321): tables for MySQL 8.0. Names mirror the original.
-- Spec guarantee (not enforced here): at least one customer visits on every day, so there are no date gaps.

CREATE TABLE Customer (
  customer_id INT,
  name        VARCHAR(100),
  visited_on  DATE,
  amount      INT,               -- amount paid on that visit
  PRIMARY KEY (customer_id, visited_on)   -- grain: one row per customer visit-day; many customers per day
);
