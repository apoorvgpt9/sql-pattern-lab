-- Typical org, four levels. Two level-2 managers with nearly equal budgets (390 vs 380), so the
-- budget sort is visible; node 6 manages one person, which makes it a manager with team_size 1.
--
--          1 Ava (300)
--         /          \
--     2 Ben (200)   3 Cara (180)
--     /     \          |
--  4 Dev   5 Eve     6 Finn (120)
--  (100)   (90)        |
--                    7 Gia (80)
INSERT INTO Employees (employee_id, employee_name, manager_id, salary, department) VALUES
  (1, 'Ava',  NULL, 300, 'Exec'),
  (2, 'Ben',  1,    200, 'Engineering'),
  (3, 'Cara', 1,    180, 'Sales'),
  (4, 'Dev',  2,    100, 'Engineering'),
  (5, 'Eve',  2,     90, 'Engineering'),
  (6, 'Finn', 3,    120, 'Sales'),
  (7, 'Gia',  6,     80, 'Sales');

-- expect: 1,Ava,1,6,1070 | CEO: level 1; reports 2..7 = 6; budget 300 + 200+180+100+90+120+80 = 1070
-- expect: 2,Ben,2,2,390 | level 2; reports 4, 5; budget 200 + 100 + 90 = 390 (sorted before Cara: 390 > 380)
-- expect: 3,Cara,2,2,380 | level 2; reports 6 (direct) and 7 (indirect); budget 180 + 120 + 80 = 380
-- expect: 6,Finn,3,1,200 | level 3; one report (7); budget 120 + 80 = 200, highest at level 3
-- expect: 4,Dev,3,0,100 | level 3 leaf: team 0, budget = own salary 100
-- expect: 5,Eve,3,0,90 | level 3 leaf: budget 90, lowest at level 3
-- expect: 7,Gia,4,0,80 | level 4 leaf: 1 -> 3 -> 6 -> 7; budget 80
