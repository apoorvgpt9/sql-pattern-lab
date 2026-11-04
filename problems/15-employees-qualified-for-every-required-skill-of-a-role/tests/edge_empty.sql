-- Roles exist but nobody has declared any skill.
INSERT INTO RoleRequirements (role, skill) VALUES ('Dev', 'SQL'), ('Dev', 'Git');

-- expect-empty: no employee holds anything, so no role has a qualified employee
