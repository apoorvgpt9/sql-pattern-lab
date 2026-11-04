-- Approach 3 (optimal): join the requirements to the claims on skill and count DISTINCT matched skills per (role, employee),
-- comparing with the number of skills THAT ROLE requires (a per-role count, not a global one).
-- The comparison sits in HAVING, so groups that fall short are discarded as they are formed and only qualifying pairs are
-- ever materialised. Duplicate claims multiply the joined rows, which COUNT(DISTINCT skill) absorbs.
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
