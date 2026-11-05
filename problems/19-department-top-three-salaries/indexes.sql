-- Index discussed in README "At scale" (b). The bench runs every solution without it, then with it.
-- (departmentId, salary) covers the ranking, the correlated count and the distinct list. What the bench's EXPLAIN
-- ANALYZE showed at 1M rows:
--   01: each "how many distinct higher salaries" probe reads the WHOLE department's entries and filters them,
--       not just the higher-salary range (sum of department sizes squared);
--   02: DISTINCT departmentId, salary becomes a streaming group over the index (02 about 2x faster);
--   03: no change. The window also needs `name`, which is not in the index, so MySQL still scans and sorts.
CREATE INDEX idx_employee_dept_salary ON Employee (departmentId, salary);
