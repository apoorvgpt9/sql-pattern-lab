-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (departmentId, salary) is covering for the MAX-per-department work in all three approaches:
--   01: each correlated MAX(salary) becomes one read at the end of a department's index range;
--   02: the GROUP BY departmentId / MAX(salary) can be answered from the index without a temp table;
--   03: the window's PARTITION BY departmentId ORDER BY salary DESC matches the index order, so
--       the sort can be skipped.
CREATE INDEX idx_employee_dept_salary ON Employee (departmentId, salary);
