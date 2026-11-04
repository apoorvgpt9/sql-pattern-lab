-- breaks: edge_typical
-- MISTAKE: requiring the employee's WHOLE skill list to equal the role's requirement count. "Extra skills are fine":
-- an employee with the required skills plus others must still qualify.
WITH claims AS (SELECT DISTINCT employee_id, skill FROM EmployeeSkills),
     total AS (SELECT employee_id, COUNT(*) AS n_total FROM claims GROUP BY employee_id),
     req AS (SELECT role, COUNT(*) AS n_required FROM RoleRequirements GROUP BY role)
SELECT rr.role, c.employee_id
FROM RoleRequirements rr
JOIN claims c ON c.skill = rr.skill
JOIN req ON req.role = rr.role
JOIN total t ON t.employee_id = c.employee_id
GROUP BY rr.role, c.employee_id, req.n_required, t.n_total
HAVING COUNT(*) = req.n_required AND t.n_total = req.n_required
ORDER BY rr.role, c.employee_id;
