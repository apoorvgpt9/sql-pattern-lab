-- Odd and Even Transactions (LeetCode 3220): tables for MySQL 8.0. Names mirror the original.
-- amount is nullable on purpose: see README "Assumptions" (a NULL amount is neither odd nor even).

CREATE TABLE transactions (
  transaction_id   INT PRIMARY KEY,   -- grain: one row per transaction
  amount           INT,
  transaction_date DATE
);
