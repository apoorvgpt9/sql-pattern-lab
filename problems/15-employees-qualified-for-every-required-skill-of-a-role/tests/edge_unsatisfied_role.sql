-- A role nobody fully satisfies (Architect: each employee has two of the three skills) produces no rows.
-- Intern needs one skill, so the same employees can still satisfy it.
INSERT INTO RoleRequirements (role, skill) VALUES
  ('Architect', 'SQL'), ('Architect', 'Terraform'), ('Architect', 'Go'),
  ('Intern', 'SQL');

INSERT INTO EmployeeSkills (employee_id, skill) VALUES
  (1, 'SQL'), (1, 'Terraform'),
  (2, 'SQL'), (2, 'Go'),
  (3, 'Terraform'), (3, 'Go'),
  (4, 'SQL'), (4, 'Terraform');

-- expect: Intern,1 | has SQL
-- expect: Intern,2 | has SQL
-- expect: Intern,4 | has SQL
-- (nobody holds all of SQL, Terraform and Go, so Architect has no rows; employee 3 has no SQL, so not an Intern)
