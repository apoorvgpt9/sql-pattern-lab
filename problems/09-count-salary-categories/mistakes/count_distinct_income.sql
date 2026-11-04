-- breaks: edge_typical
-- MISTAKE: COUNT(DISTINCT income) "to be safe". Two different accounts with the same income are two accounts.
SELECT 'Low Salary' AS category, COUNT(DISTINCT income) AS accounts_count FROM Accounts WHERE income < 20000
UNION ALL
SELECT 'Average Salary', COUNT(DISTINCT income) FROM Accounts WHERE income BETWEEN 20000 AND 50000
UNION ALL
SELECT 'High Salary', COUNT(DISTINCT income) FROM Accounts WHERE income > 50000;
