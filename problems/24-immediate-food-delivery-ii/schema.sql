-- Immediate Food Delivery II (LeetCode 1174): tables for MySQL 8.0. Names mirror the original.
-- Spec guarantees: customer_pref_delivery_date >= order_date, and each customer's FIRST order date
-- is unique (their earliest order_date appears once). Later orders may share a date.

CREATE TABLE Delivery (
  delivery_id                 INT PRIMARY KEY,   -- grain: one row per order
  customer_id                 INT NOT NULL,
  order_date                  DATE NOT NULL,
  customer_pref_delivery_date DATE NOT NULL
);
