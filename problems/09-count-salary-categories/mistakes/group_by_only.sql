-- breaks: edge_missing_categories, edge_empty, edge_nulls
-- MISTAKE: classify and GROUP BY, with no scaffold. A category that nobody falls into has no group,
-- so it is missing from the output instead of being reported with 0.
-- (edge_nulls: the NULL-income group is also reported, as a NULL-category row.)
SELECT
  CASE
    WHEN income < 20000                 THEN 'Low Salary'
    WHEN income BETWEEN 20000 AND 50000 THEN 'Average Salary'
    WHEN income > 50000                 THEN 'High Salary'
  END AS category,
  COUNT(*) AS accounts_count
FROM Accounts
GROUP BY 1;
