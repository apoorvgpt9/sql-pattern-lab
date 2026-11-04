-- Approach 3 (optimal): deduplicate the claims BEFORE the join, so each (employee, skill) occurs once and the number of
-- matched rows is the number of matched skills: COUNT(*) replaces COUNT(DISTINCT), and duplicate claims never enter the join.
-- Per-role requirement counts come from a one-row-per-role CTE joined 1:1.
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
