-- breaks: edge_exact_match
-- MISTAKE: "cleaning" the strings before matching, LOWER(TRIM(...)). The spec says matching is exact string equality,
-- so 'sql' and 'SQL ' are different skills from 'SQL'.
WITH claims AS (SELECT DISTINCT employee_id, LOWER(TRIM(skill)) AS skill FROM EmployeeSkills),
     req AS (SELECT role, COUNT(*) AS n_required FROM RoleRequirements GROUP BY role)
SELECT rr.role, c.employee_id
FROM RoleRequirements rr
JOIN claims c ON c.skill = LOWER(TRIM(rr.skill))
JOIN req ON req.role = rr.role
GROUP BY rr.role, c.employee_id, req.n_required
HAVING COUNT(*) = req.n_required
ORDER BY rr.role, c.employee_id;
