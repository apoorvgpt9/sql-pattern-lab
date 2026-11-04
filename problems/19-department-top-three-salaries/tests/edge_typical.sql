-- Typical mix: a department with five distinct salaries (the bottom two are cut), a department with
-- fewer than three people, and a one-person department. Rows are inserted in no particular order.
INSERT INTO Department (id, name) VALUES (1, 'IT'), (2, 'Sales'), (3, 'HR');

INSERT INTO Employee (id, name, salary, departmentId) VALUES
  (4, 'Di',  70000,  1),
  (7, 'Gus', 40000,  2),
  (2, 'Bob', 90000,  1),
  (8, 'Hal', 77000,  3),
  (1, 'Ann', 100000, 1),
  (5, 'Eve', 60000,  1),
  (6, 'Fay', 50000,  2),
  (3, 'Cy',  80000,  1);

-- expect: IT,Ann,100000 | 1st distinct salary in IT
-- expect: IT,Bob,90000 | 2nd distinct salary in IT
-- expect: IT,Cy,80000 | 3rd distinct salary in IT (the last one allowed)
-- expect: Sales,Fay,50000 | Sales has only 2 distinct salaries: everyone is in the top three
-- expect: Sales,Gus,40000 | same
-- expect: HR,Hal,77000 | one-person department
-- (Di at 70000 and Eve at 60000 are the 4th and 5th distinct IT salaries and are cut.)
