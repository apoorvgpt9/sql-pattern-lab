-- Two roles of different sizes. Employee 1 has every skill of both roles plus extras; employee 4 qualifies only for
-- Engineer; employee 3 is one skill short of each role; employee 5 has none of the SQL skills.
INSERT INTO RoleRequirements (role, skill) VALUES
  ('Analyst', 'SQL'), ('Analyst', 'Excel'),
  ('Engineer', 'SQL'), ('Engineer', 'Python'), ('Engineer', 'Git');

INSERT INTO EmployeeSkills (employee_id, skill) VALUES
  (1, 'SQL'), (1, 'Excel'), (1, 'Python'), (1, 'Git'),
  (2, 'SQL'), (2, 'Excel'),
  (3, 'SQL'), (3, 'Python'),
  (4, 'Python'), (4, 'Git'), (4, 'SQL'),
  (5, 'Excel');

-- expect: Analyst,1 | has SQL and Excel (extra skills are fine)
-- expect: Analyst,2 | has exactly SQL and Excel
-- expect: Engineer,1 | has SQL, Python and Git: one employee can qualify for several roles
-- expect: Engineer,4 | has Python, Git and SQL, listed in a different order
-- (employee 3 lacks Git and Excel, employee 5 lacks SQL; employee 2 lacks Python and Git)
