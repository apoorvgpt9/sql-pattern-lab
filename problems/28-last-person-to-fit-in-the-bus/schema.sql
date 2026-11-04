-- Last Person to Fit in the Bus (LeetCode 1204): tables for MySQL 8.0. Names mirror the original.
-- Spec guarantees (not enforced here): turn is unique and runs 1..n; weights are positive; capacity is 1000.

CREATE TABLE Queue (
  person_id   INT PRIMARY KEY,   -- grain: one row per person waiting
  person_name VARCHAR(100),
  weight      INT,
  turn        INT                -- boarding order, 1..n
);
