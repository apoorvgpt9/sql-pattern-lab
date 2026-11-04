-- Typical mix: three departments with different sizes, a salary in one department that equals
-- another department's maximum (the trap for joining on salary alone), and a second-best salary.
INSERT INTO Department (id, name) VALUES (1, 'IT'), (2, 'Sales'), (3, 'HR');

INSERT INTO Employee (id, name, salary, departmentId) VALUES
  (1, 'Joe',   70000, 1),
  (2, 'Jim',   90000, 1),
  (3, 'Henry', 80000, 2),
  (4, 'Sam',   60000, 2),
  (5, 'Max',   90000, 2),  -- 90000 is also the IT maximum, but here it is the Sales maximum
  (6, 'Ann',   70000, 3);  -- 70000 equals Joe's salary in IT, but Ann is the only HR employee

-- expect: IT,Jim,90000 | highest in department 1 (Joe's 70000 is lower)
-- expect: Sales,Max,90000 | highest in department 2 (Henry 80000 and Sam 60000 are lower)
-- expect: HR,Ann,70000 | the only HR employee is trivially the maximum
