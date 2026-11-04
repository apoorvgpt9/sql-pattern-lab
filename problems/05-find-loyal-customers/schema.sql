-- Find Loyal Customers: tables for MySQL 8.0. Names mirror the original.
-- All columns NOT NULL (the spec expects no NULLs); transaction_type is limited to the two documented values.

CREATE TABLE customer_transactions (
  transaction_id   INT PRIMARY KEY,               -- grain: one row per transaction
  customer_id      INT NOT NULL,
  transaction_date DATE NOT NULL,
  amount           DECIMAL(10,2) NOT NULL,
  transaction_type VARCHAR(20) NOT NULL,          -- 'purchase' or 'refund'
  CONSTRAINT chk_transaction_type CHECK (transaction_type IN ('purchase', 'refund'))
);
