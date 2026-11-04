-- Ordering: role ASC, then employee_id ASC (numeric). Rows are inserted scrambled; employee ids 3, 20, 100.
-- Sorted by employee first, the output would interleave the roles.
INSERT INTO RoleRequirements (role, skill) VALUES ('Zeta', 'b'), ('Alpha', 'a'), ('Zeta', 'a');

INSERT INTO EmployeeSkills (employee_id, skill) VALUES
  (100, 'a'), (20, 'a'), (3, 'b'), (100, 'b'), (3, 'a');

-- expect: Alpha,3 | role Alpha needs only skill a: employees 3, 20 and 100 all have it; smallest id first
-- expect: Alpha,20 | next id (numeric order: 20 before 100)
-- expect: Alpha,100 | last Alpha row
-- expect: Zeta,3 | role Zeta needs a and b: employee 3 has both
-- expect: Zeta,100 | employee 100 has both (employee 20 lacks b)
