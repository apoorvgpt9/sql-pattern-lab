-- Consecutive Numbers (LeetCode 180): tables for MySQL 8.0. Names mirror the original.
-- The spec describes id as an auto-increment starting at 1; the harness inserts explicit ids,
-- and one edge dataset leaves gaps on purpose (see README "Assumptions").

CREATE TABLE Logs (
  id  INT PRIMARY KEY,        -- grain: one row per log entry
  num VARCHAR(100)
);
