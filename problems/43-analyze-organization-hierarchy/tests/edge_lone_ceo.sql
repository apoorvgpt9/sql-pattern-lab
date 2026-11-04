-- A company of one: the CEO manages nobody. team_size must be 0 (not NULL, not 1) and budget the
-- CEO's own salary (not NULL).
INSERT INTO Employees (employee_id, employee_name, manager_id, salary, department) VALUES
  (1, 'Solo', NULL, 250, 'Exec');

-- expect: 1,Solo,1,0,250 | level 1, no reports, budget = own salary
