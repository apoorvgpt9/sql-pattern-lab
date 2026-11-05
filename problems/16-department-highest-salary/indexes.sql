-- Index discussed in README "At scale" (b). The bench runs every solution without it, then with it.
-- (departmentId, salary) is covering for the MAX-per-department work. What the bench's EXPLAIN ANALYZE showed at 1M rows:
--   01: each correlated MAX(salary) does a covering index lookup, but it reads ALL of the department's entries
--       (not just the last one), so the work is sum of department sizes squared;
--   02: the GROUP BY departmentId / MAX(salary) becomes a covering skip scan, and the join back is an index lookup;
--       this makes 02 the fastest approach with the index;
--   03: no change. The window also needs `name`, which is not in the index, so MySQL still scans and sorts.
CREATE INDEX idx_employee_dept_salary ON Employee (departmentId, salary);
