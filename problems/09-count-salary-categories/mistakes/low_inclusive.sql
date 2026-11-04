-- breaks: edge_boundaries
-- MISTAKE: Low written as income <= 20000. The spec says Low is strictly below 20000 and Average
-- starts AT 20000, so accounts on the cut-off are double-counted (in Low and in Average).
SELECT 'Low Salary' AS category, COUNT(*) AS accounts_count FROM Accounts WHERE income <= 20000
UNION ALL
SELECT 'Average Salary', COUNT(*) FROM Accounts WHERE income BETWEEN 20000 AND 50000
UNION ALL
SELECT 'High Salary', COUNT(*) FROM Accounts WHERE income > 50000;
