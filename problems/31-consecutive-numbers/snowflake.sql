-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same island construction as MySQL. Alternatives (CONDITIONAL_TRUE_EVENT, QUALIFY) are in README section 9.
WITH numbered AS (
  SELECT num,
         ROW_NUMBER() OVER (ORDER BY id)
         - ROW_NUMBER() OVER (PARTITION BY num ORDER BY id) AS island
  FROM Logs
),
runs AS (
  SELECT num, island, COUNT(*) AS run_length
  FROM numbered
  GROUP BY num, island
)
SELECT DISTINCT num AS ConsecutiveNums
FROM runs
WHERE run_length >= 3;
