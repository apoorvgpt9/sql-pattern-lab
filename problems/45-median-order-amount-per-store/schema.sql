-- Median Order Amount per Store (SPL-MED-01, written for this repo): tables for MySQL 8.0.

CREATE TABLE StoreOrders (
  order_id INT PRIMARY KEY,         -- grain: one row per order
  store_id INT NOT NULL,
  amount   DECIMAL(10,2) NOT NULL   -- never NULL (spec); exact decimal arithmetic for the median
);
