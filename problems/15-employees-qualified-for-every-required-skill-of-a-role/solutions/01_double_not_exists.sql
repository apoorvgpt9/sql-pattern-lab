-- Approach 1 (brute force): division from its definition, for every (role, employee) candidate.
-- An employee qualifies for a role when there is NO required skill of that role for which there is NO matching claim.
-- Tries every role x employee combination: roles x employees x required skills probes.
SELECT r.role, e.employee_id
FROM (SELECT DISTINCT role FROM RoleRequirements) r
CROSS JOIN (SELECT DISTINCT employee_id FROM EmployeeSkills) e
WHERE NOT EXISTS (
  SELECT 1
  FROM RoleRequirements rr
  WHERE rr.role = r.role
    AND NOT EXISTS (
      SELECT 1
      FROM EmployeeSkills es
      WHERE es.employee_id = e.employee_id
        AND es.skill = rr.skill
    )
)
ORDER BY r.role, e.employee_id;
