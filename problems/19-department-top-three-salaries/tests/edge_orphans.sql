-- Employees with no usable department, and a department with no employees. The orphans are the best
-- paid people, so a ranking that ignores the department ("global top three") puts them first.
INSERT INTO Department (id, name) VALUES (1, 'IT'), (2, 'Empty');

INSERT INTO Employee (id, name, salary, departmentId) VALUES
  (1, 'Joe',    70000, 1),
  (2, 'Jim',    60000, 1),
  (3, 'Nobody', 99000, NULL),  -- no department
  (4, 'Ghost',  98000, 7);     -- department 7 does not exist

-- expect: IT,Joe,70000 | IT has two distinct salaries, so both people are in
-- expect: IT,Jim,60000 | same; Nobody and Ghost have no department row to be named under
