-- A six-level chain 1 -> 2 -> 3 -> 4 -> 5 -> 6. Every manager has exactly one DIRECT report but up
-- to five reports in total: a direct-reports-only query gets every team_size and budget wrong.
INSERT INTO Employees (employee_id, employee_name, manager_id, salary, department) VALUES
  (1, 'Ann', NULL, 60, 'Exec'),
  (2, 'Bo',  1,    50, 'Ops'),
  (3, 'Cy',  2,    40, 'Ops'),
  (4, 'Di',  3,    30, 'Ops'),
  (5, 'Ed',  4,    20, 'Ops'),
  (6, 'Flo', 5,    10, 'Ops');

-- expect: 1,Ann,1,5,210 | reports 2..6; budget 60+50+40+30+20+10 = 210
-- expect: 2,Bo,2,4,150 | reports 3..6; 50+40+30+20+10 = 150
-- expect: 3,Cy,3,3,100 | reports 4..6; 40+30+20+10 = 100
-- expect: 4,Di,4,2,60 | reports 5, 6; 30+20+10 = 60
-- expect: 5,Ed,5,1,30 | report 6; 20+10 = 30
-- expect: 6,Flo,6,0,10 | leaf at level 6; own salary
