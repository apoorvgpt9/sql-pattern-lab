-- breaks: edge_missing_categories, edge_empty, edge_nulls
-- MISTAKE: scaffold LEFT JOIN Accounts, then COUNT(*). An empty category still produces one
-- joined row (all Accounts columns NULL), so COUNT(*) reports 1 instead of 0. COUNT(a.account_id) is correct.
SELECT s.category, COUNT(*) AS accounts_count
FROM (SELECT 'Low Salary' AS category UNION ALL SELECT 'Average Salary' UNION ALL SELECT 'High Salary') s
LEFT JOIN Accounts a
  ON  (s.category = 'Low Salary'     AND a.income < 20000)
  OR  (s.category = 'Average Salary' AND a.income BETWEEN 20000 AND 50000)
  OR  (s.category = 'High Salary'    AND a.income > 50000)
GROUP BY s.category;
