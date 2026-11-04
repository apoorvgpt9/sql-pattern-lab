-- breaks: edge_boundaries
-- MISTAKE: Average written as 20000 < income < 50000. Both end points belong to Average, so accounts
-- at exactly 20000 or 50000 fall into no category at all.
SELECT 'Low Salary' AS category, COUNT(*) AS accounts_count FROM Accounts WHERE income < 20000
UNION ALL
SELECT 'Average Salary', COUNT(*) FROM Accounts WHERE income > 20000 AND income < 50000
UNION ALL
SELECT 'High Salary', COUNT(*) FROM Accounts WHERE income > 50000;
