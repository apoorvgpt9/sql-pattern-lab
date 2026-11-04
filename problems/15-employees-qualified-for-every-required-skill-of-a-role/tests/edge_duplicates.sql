-- Exact duplicate rows in EmployeeSkills. Role Dev needs SQL and Git (2 skills).
-- Employee 1: SQL twice and nothing else -> 2 matching ROWS but only 1 skill. Employee 2: SQL once and Git twice -> 3 rows, 2 skills.
INSERT INTO RoleRequirements (role, skill) VALUES ('Dev', 'SQL'), ('Dev', 'Git');

INSERT INTO EmployeeSkills (employee_id, skill) VALUES
  (1, 'SQL'), (1, 'SQL'),
  (2, 'SQL'), (2, 'Git'), (2, 'Git'),
  (3, 'SQL'), (3, 'Git');

-- expect: Dev,2 | holds both SQL and Git (three rows, two distinct skills)
-- expect: Dev,3 | holds both SQL and Git
-- (employee 1 has two rows but only the SQL skill, so a row count equal to the requirement count would let them through)
