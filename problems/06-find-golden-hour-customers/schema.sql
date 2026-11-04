-- Find Golden Hour Customers: tables for MySQL 8.0. Names mirror the original.
-- order_rating is the only nullable column (NULL = the order was not rated). A rating is 1-5.

CREATE TABLE restaurant_orders (
  order_id        INT PRIMARY KEY,                 -- grain: one row per order
  customer_id     INT NOT NULL,
  order_timestamp DATETIME NOT NULL,
  order_amount    DECIMAL(10,2) NOT NULL,
  payment_method  VARCHAR(10) NOT NULL,            -- cash | card | app
  order_rating    INT NULL,
  CONSTRAINT chk_rating CHECK (order_rating IS NULL OR order_rating BETWEEN 1 AND 5)
);
