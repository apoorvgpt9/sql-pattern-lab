-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- QUALIFY filters on a window function directly, so the ranked CTE disappears.
SELECT
  d.name    AS "Department",
  e.name    AS "Employee",
  e.salary  AS "Salary"
FROM Employee e
JOIN Department d
  ON d.id = e.departmentId
QUALIFY RANK() OVER (PARTITION BY e.departmentId ORDER BY e.salary DESC) = 1;
