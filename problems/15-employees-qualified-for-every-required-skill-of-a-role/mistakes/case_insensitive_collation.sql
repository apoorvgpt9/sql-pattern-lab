-- breaks: edge_exact_match
-- MISTAKE: comparing under MySQL's default case- and accent-insensitive collation (COLLATE utf8mb4_0900_ai_ci), which is
-- what a plain VARCHAR column would have given. 'sql' = 'SQL' there, so employees 1 and 4 get through. (That collation
-- does not pad, so 'SQL ' still differs; utf8mb4_bin or latin1 collations would pad and equate 'SQL ' with 'SQL'.)
WITH claims AS (SELECT DISTINCT employee_id, skill FROM EmployeeSkills),
     req AS (SELECT role, COUNT(*) AS n_required FROM RoleRequirements GROUP BY role)
SELECT rr.role, c.employee_id
FROM RoleRequirements rr
JOIN claims c ON c.skill COLLATE utf8mb4_0900_ai_ci = rr.skill COLLATE utf8mb4_0900_ai_ci
JOIN req ON req.role = rr.role
GROUP BY rr.role, c.employee_id, req.n_required
HAVING COUNT(*) = req.n_required
ORDER BY rr.role, c.employee_id;
