-- Count Salary Categories (LeetCode 1907): tables for MySQL 8.0. Names mirror the original.
-- income is nullable on purpose: see README "Assumptions" (a NULL income belongs to no category).

CREATE TABLE Accounts (
  account_id INT PRIMARY KEY,   -- grain: one row per account
  income     INT
);
