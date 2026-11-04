-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same pivot-then-unpivot shape; differences are noted in README section 9.
-- COUNT_IF replaces COUNT(CASE ... THEN 1 END); the VALUES-based scaffold can also be written as a literal table.
WITH c AS (
  SELECT
    COUNT_IF(income < 20000)                  AS low_n,
    COUNT_IF(income BETWEEN 20000 AND 50000)  AS avg_n,
    COUNT_IF(income > 50000)                  AS high_n
  FROM Accounts
)
SELECT 'Low Salary'     AS category, low_n  AS accounts_count FROM c
UNION ALL
SELECT 'Average Salary', avg_n  FROM c
UNION ALL
SELECT 'High Salary',    high_n FROM c;
