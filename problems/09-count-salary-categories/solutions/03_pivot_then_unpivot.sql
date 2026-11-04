-- Approach 3 (optimal): one scan, no GROUP BY, no join.
-- Step 1 pivots: a scalar aggregate always returns exactly one row (COUNT of nothing is 0), holding
--   all three counts as columns. COUNT(CASE ...) skips NULLs, and a NULL income matches no branch.
-- Step 2 unpivots that single row into the three output rows. The "scaffold" is the UNION ALL itself.
WITH c AS (
  SELECT
    COUNT(CASE WHEN income < 20000                 THEN 1 END) AS low_n,
    COUNT(CASE WHEN income BETWEEN 20000 AND 50000 THEN 1 END) AS avg_n,
    COUNT(CASE WHEN income > 50000                 THEN 1 END) AS high_n
  FROM Accounts
)
SELECT 'Low Salary'     AS category, low_n  AS accounts_count FROM c
UNION ALL
SELECT 'Average Salary', avg_n  FROM c
UNION ALL
SELECT 'High Salary',    high_n FROM c;
