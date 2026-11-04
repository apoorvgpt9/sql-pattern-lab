-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (employee_id, meeting_date, duration_hours) is covering for all three solutions:
--   01: each employee's correlated subquery becomes an index range read of that employee's
--       meetings instead of a full scan of meetings per employee;
--   02, 03: the (employee, week) GROUP BY reads meetings in (employee_id, meeting_date) order, and
--       the week key is a monotonic function of meeting_date within an employee.
CREATE INDEX idx_meetings_emp_date_hours ON meetings (employee_id, meeting_date, duration_hours);
