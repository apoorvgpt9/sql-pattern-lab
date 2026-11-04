-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (manager_id) answers "who reports directly to X?" as an index range read. That is the question
-- every DOWNWARD recursive step asks:
--   01/02: both the levels CTE and the reports closure walk down; without this index each iteration
--          is a hash join over a full scan of Employees (one full scan per level of the org).
--   03:    walks UP via the primary key and never asks that question; expect little change.
CREATE INDEX idx_employees_manager ON Employees (manager_id);
