-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same island label as MySQL; QUALIFY removes the second CTE. Differences are in README section 9.
WITH busy AS (
  SELECT id, visit_date, people,
         id - ROW_NUMBER() OVER (ORDER BY id) AS island
  FROM Stadium
  WHERE people >= 100
)
SELECT id, visit_date, people
FROM busy
QUALIFY COUNT(*) OVER (PARTITION BY island) >= 3
ORDER BY visit_date;
