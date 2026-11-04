-- "Exact string equality": 'sql' is not 'SQL', and 'SQL ' (trailing space) is not 'SQL'.
-- This only holds because the skill columns use a binary collation (schema.sql); the default collation would match all four.
INSERT INTO RoleRequirements (role, skill) VALUES ('QA', 'SQL'), ('QA', 'Selenium');

INSERT INTO EmployeeSkills (employee_id, skill) VALUES
  (1, 'sql'),  (1, 'Selenium'),     -- wrong case on SQL
  (2, 'SQL '), (2, 'Selenium'),     -- trailing space on SQL
  (3, 'SQL'),  (3, 'Selenium'),     -- exact
  (4, 'SQL'),  (4, 'selenium');     -- wrong case on Selenium

-- expect: QA,3 | the only employee whose two skill strings match the requirements byte for byte
