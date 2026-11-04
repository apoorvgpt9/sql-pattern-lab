-- breaks: edge_missing_categories, edge_empty, edge_nulls
-- MISTAKE: scaffold INNER JOIN counts. The scaffold is there to keep rows that have no partner;
-- an inner join removes exactly those rows again.
WITH counts AS (
  SELECT
    CASE
      WHEN income < 20000                 THEN 'Low Salary'
      WHEN income BETWEEN 20000 AND 50000 THEN 'Average Salary'
      WHEN income > 50000                 THEN 'High Salary'
    END AS category,
    COUNT(*) AS n
  FROM Accounts
  GROUP BY 1
)
SELECT s.category, c.n AS accounts_count
FROM (SELECT 'Low Salary' AS category UNION ALL SELECT 'Average Salary' UNION ALL SELECT 'High Salary') s
JOIN counts c ON c.category = s.category;
