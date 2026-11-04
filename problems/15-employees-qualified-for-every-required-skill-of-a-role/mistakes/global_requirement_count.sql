-- breaks: edge_typical
-- MISTAKE: comparing with ONE global number of required skills (all distinct skills of all roles) instead of the count
-- for each role. "For each role" means the target set depends on the group. Here the global count is 4, and nobody
-- can match 4 skills within a role that requires 2 or 3.
SELECT rr.role, es.employee_id
FROM RoleRequirements rr
JOIN EmployeeSkills es ON es.skill = rr.skill
GROUP BY rr.role, es.employee_id
HAVING COUNT(DISTINCT rr.skill) = (SELECT COUNT(DISTINCT skill) FROM RoleRequirements)
ORDER BY rr.role, es.employee_id;
