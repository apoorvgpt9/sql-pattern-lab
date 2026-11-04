-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL. Snowflake compares strings case-sensitively and without padding by default, which is the
-- "exact string equality" the spec asks for, so no collation clause is needed (see README section 9).
WITH claims AS (
  SELECT DISTINCT employee_id, skill FROM EmployeeSkills
),
req AS (
  SELECT role, COUNT(*) AS n_required
  FROM RoleRequirements
  GROUP BY role
),
hits AS (
  SELECT rr.role, c.employee_id, COUNT(*) AS n_hit
  FROM RoleRequirements rr
  JOIN claims c ON c.skill = rr.skill
  GROUP BY rr.role, c.employee_id
)
SELECT h.role, h.employee_id
FROM hits h
JOIN req ON req.role = h.role
WHERE h.n_hit = req.n_required
ORDER BY h.role, h.employee_id;
