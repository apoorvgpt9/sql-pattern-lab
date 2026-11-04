-- Indexes recommended in README "At scale" (b). The bench runs every solution without them, then with them.
-- EmployeeSkills is a heap (no primary key). (skill, employee_id) lets the join from a required skill find the
-- employees holding it and read employee_id from the index alone; (employee_id, skill) turns approach 1's innermost
-- "does this employee hold this skill?" into a point lookup.
CREATE INDEX idx_es_skill_emp ON EmployeeSkills (skill, employee_id);
CREATE INDEX idx_es_emp_skill ON EmployeeSkills (employee_id, skill);
