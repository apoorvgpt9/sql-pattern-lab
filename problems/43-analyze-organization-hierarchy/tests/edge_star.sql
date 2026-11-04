-- A flat org: the CEO has four direct reports and no one else. Three reports earn the same salary,
-- so they tie on (level, budget) and are ordered by name.
INSERT INTO Employees (employee_id, employee_name, manager_id, salary, department) VALUES
  (1, 'Hal', NULL, 1000, 'Exec'),
  (2, 'Uma', 1,      70, 'Ops'),
  (3, 'Ola', 1,      70, 'Ops'),
  (4, 'Ike', 1,      70, 'Ops'),
  (5, 'Ned', 1,      90, 'Ops');

-- expect: 1,Hal,1,4,1300 | four direct reports; 1000 + 70+70+70+90 = 1300
-- expect: 5,Ned,2,0,90 | level 2, highest budget (90)
-- expect: 4,Ike,2,0,70 | level 2, budget 70 tie: 'Ike' < 'Ola' < 'Uma'
-- expect: 3,Ola,2,0,70 | same tie, second by name
-- expect: 2,Uma,2,0,70 | same tie, last by name
