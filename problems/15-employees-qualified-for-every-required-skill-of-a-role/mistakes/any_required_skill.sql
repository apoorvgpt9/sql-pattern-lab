-- breaks: edge_typical, edge_unsatisfied_role, edge_duplicates, edge_exact_match
-- MISTAKE: returning every (role, employee) pair with at least one matching skill - "has a required skill" instead of
-- "has every required skill". Missing the HAVING that compares counts.
SELECT DISTINCT rr.role, es.employee_id
FROM RoleRequirements rr
JOIN EmployeeSkills es ON es.skill = rr.skill
ORDER BY rr.role, es.employee_id;
