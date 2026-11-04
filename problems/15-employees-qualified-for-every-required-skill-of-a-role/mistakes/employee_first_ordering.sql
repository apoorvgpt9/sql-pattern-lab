-- breaks: edge_ordering
-- MISTAKE: ORDER BY employee_id, role. The spec orders by role first.
WITH claims AS (SELECT DISTINCT employee_id, skill FROM EmployeeSkills),
     req AS (SELECT role, COUNT(*) AS n_required FROM RoleRequirements GROUP BY role)
SELECT rr.role, c.employee_id
FROM RoleRequirements rr
JOIN claims c ON c.skill = rr.skill
JOIN req ON req.role = rr.role
GROUP BY rr.role, c.employee_id, req.n_required
HAVING COUNT(*) = req.n_required
ORDER BY c.employee_id, rr.role;
