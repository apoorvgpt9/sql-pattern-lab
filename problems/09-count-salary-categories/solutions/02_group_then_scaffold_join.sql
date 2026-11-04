-- Approach 2: classify each account, count per category, then LEFT JOIN the counts onto a
-- hand-built 3-row scaffold so that empty categories still appear (with 0).
-- NULL income matches no WHEN, so its category is NULL; the scaffold never matches NULL, so it is dropped.
WITH counts AS (
  SELECT
    CASE
      WHEN income < 20000                  THEN 'Low Salary'
      WHEN income BETWEEN 20000 AND 50000  THEN 'Average Salary'
      WHEN income > 50000                  THEN 'High Salary'
    END AS category,
    COUNT(*) AS n
  FROM Accounts
  GROUP BY 1
),
scaffold AS (
  SELECT 'Low Salary' AS category
  UNION ALL SELECT 'Average Salary'
  UNION ALL SELECT 'High Salary'
)
SELECT s.category, COALESCE(c.n, 0) AS accounts_count
FROM scaffold s
LEFT JOIN counts c ON c.category = s.category;
