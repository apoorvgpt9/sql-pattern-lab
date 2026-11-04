-- Tree Node (LeetCode 608): tables for MySQL 8.0. Names mirror the original.
-- No foreign key from p_id to id, as on LeetCode. The data is a valid tree: exactly one row has
-- p_id NULL (the root) and every other p_id names an existing id.

CREATE TABLE Tree (
  id   INT PRIMARY KEY,   -- grain: one row per node
  p_id INT                -- parent id; NULL for the root
);
