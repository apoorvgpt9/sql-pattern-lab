-- Rows that match nothing: a department with no employees, an employee with a NULL departmentId,
-- and an employee pointing at a department id that does not exist. The orphans are the best-paid
-- people in the table, so a query that ignores departments (global maximum) picks them.
INSERT INTO Department (id, name) VALUES (1, 'IT'), (2, 'Empty');

INSERT INTO Employee (id, name, salary, departmentId) VALUES
  (1, 'Joe',    70000, 1),
  (2, 'Jim',    60000, 1),
  (3, 'Nobody', 99000, NULL),  -- no department: belongs in no output group
  (4, 'Ghost',  98000, 7);     -- department 7 does not exist: cannot be named, so not output

-- expect: IT,Joe,70000 | maximum of the only department that has employees; Nobody and Ghost are paid more but have no department row
