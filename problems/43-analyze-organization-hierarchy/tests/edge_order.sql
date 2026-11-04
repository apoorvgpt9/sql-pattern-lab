-- Ordering test for (level ASC, budget DESC, employee_name ASC), rows inserted shuffled:
-- * level beats budget: Abe (level 3, budget 400) comes after Lou and Mia (level 2, budget 100);
-- * budget beats name at the same level: Pat (450) comes before Lou and Mia;
-- * name breaks an exact budget tie: Lou before Mia (both 100 at level 2).
-- No two rows tie on all three keys.
INSERT INTO Employees (employee_id, employee_name, manager_id, salary, department) VALUES
  (50, 'Abe', 40,   400, 'R&D'),
  (20, 'Mia', 10,   100, 'Support'),
  (10, 'Zed', NULL, 500, 'Exec'),
  (40, 'Pat', 10,    50, 'R&D'),
  (30, 'Lou', 10,   100, 'Support');

-- expect: 10,Zed,1,4,1150 | level 1; reports 20, 30, 40, 50; budget 500+100+100+50+400 = 1150
-- expect: 40,Pat,2,1,450 | level 2, budget 50 + 400 = 450: first at level 2 despite the lowest salary
-- expect: 30,Lou,2,0,100 | level 2, budget 100, ties with Mia; 'Lou' < 'Mia'
-- expect: 20,Mia,2,0,100 | level 2, budget 100, after Lou by name
-- expect: 50,Abe,3,0,400 | level 3; budget 400 is larger than Lou's and Mia's but level sorts first
