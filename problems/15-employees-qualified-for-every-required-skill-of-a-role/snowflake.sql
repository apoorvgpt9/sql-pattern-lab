-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL. Snowflake compares strings case-sensitively and without padding by default, which is the
-- "exact string equality" the spec asks for, so no collation clause is needed (see README section 9).
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
