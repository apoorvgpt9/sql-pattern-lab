-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Differences are noted in README section 9. The two GROUP BYs over the same closure are folded into
-- one UNION ALL + conditional aggregation so the closure is scanned once even if the CTE is inlined.
WITH RECURSIVE chain (employee_id, salary, ancestor) AS (
  SELECT employee_id, salary, manager_id
  FROM Employees
  WHERE manager_id IS NOT NULL
  UNION ALL
  SELECT c.employee_id, c.salary, m.manager_id
  FROM chain c
  JOIN Employees m ON m.employee_id = c.ancestor
  WHERE m.manager_id IS NOT NULL
),
per_person AS (
  SELECT person,
         COUNT_IF(role = 'manager')            AS team_size,
         SUM(IFF(role = 'manager', salary, 0)) AS team_salary,
         COUNT_IF(role = 'report')             AS n_above
  FROM (SELECT ancestor AS person, 'manager' AS role, salary FROM chain
        UNION ALL
        SELECT employee_id, 'report', salary FROM chain)
  GROUP BY person
)
SELECT e.employee_id,
       e.employee_name,
       1 + ZEROIFNULL(p.n_above)            AS level,
       ZEROIFNULL(p.team_size)              AS team_size,
       e.salary + ZEROIFNULL(p.team_salary) AS budget
FROM Employees e
LEFT JOIN per_person p ON p.person = e.employee_id
ORDER BY level ASC, budget DESC, e.employee_name ASC;
