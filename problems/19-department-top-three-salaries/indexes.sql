-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (departmentId, salary) covers every approach (no other Employee column is needed to rank or count):
--   01: each "how many distinct higher salaries" probe is a range read inside one department's entries;
--   02: DISTINCT departmentId, salary can be read straight from the index without a temp table;
--   03: PARTITION BY departmentId ORDER BY salary DESC matches the index, so the sort can be avoided.
CREATE INDEX idx_employee_dept_salary ON Employee (departmentId, salary);
