-- breaks: edge_duplicates
-- MISTAKE: COUNT(*) on the raw join. Duplicate claims inflate the count: an employee with the same skill twice
-- looks as if they covered two skills (false positive), and one with an extra duplicate overshoots the "=" (false negative).
WITH req AS (SELECT role, COUNT(*) AS n_required FROM RoleRequirements GROUP BY role)
SELECT rr.role, es.employee_id
FROM RoleRequirements rr
JOIN EmployeeSkills es ON es.skill = rr.skill
JOIN req ON req.role = rr.role
GROUP BY rr.role, es.employee_id, req.n_required
HAVING COUNT(*) = req.n_required
ORDER BY rr.role, es.employee_id;
