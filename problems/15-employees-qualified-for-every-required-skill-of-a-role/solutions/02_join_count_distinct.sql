-- Approach 2: join employees to the skills they match, per role, and count DISTINCT matched skills; compare with the
-- number of skills THAT ROLE requires (a per-role count, not a global one).
-- Duplicate claims multiply the joined rows, so COUNT(DISTINCT skill) is needed to count skills, not rows.
WITH req AS (
  SELECT role, COUNT(*) AS n_required
  FROM RoleRequirements
  GROUP BY role
)
SELECT rr.role, es.employee_id
FROM RoleRequirements rr
JOIN EmployeeSkills es ON es.skill = rr.skill
JOIN req ON req.role = rr.role
GROUP BY rr.role, es.employee_id, req.n_required
HAVING COUNT(DISTINCT rr.skill) = req.n_required
ORDER BY rr.role, es.employee_id;
