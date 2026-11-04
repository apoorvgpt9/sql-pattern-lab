-- Boundaries: a one-employee department, and a department whose maximum is the smallest value
-- in the table (0), which a query that seeds a running maximum with 0 or compares to a default fails on.
INSERT INTO Department (id, name) VALUES (1, 'Solo'), (2, 'Interns');

INSERT INTO Employee (id, name, salary, departmentId) VALUES
  (1, 'Una',  100, 1),
  (2, 'Ivy',  0,   2),
  (3, 'Ian',  0,   2);

-- expect: Solo,Una,100 | single employee is the maximum of its department
-- expect: Interns,Ivy,0 | maximum is 0, shared with Ian
-- expect: Interns,Ian,0 | tied at the maximum of 0
