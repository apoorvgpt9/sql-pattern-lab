-- breaks: edge_nulls
-- MISTAKE: the last CASE branch written as ELSE 'High Salary' ("everything else must be high").
-- A NULL income is not provably high; this sends every unknown income to the top bucket.
SELECT 'Low Salary' AS category, COUNT(*) AS accounts_count FROM Accounts WHERE income < 20000
UNION ALL
SELECT 'Average Salary', COUNT(*) FROM Accounts WHERE income BETWEEN 20000 AND 50000
UNION ALL
SELECT 'High Salary', COUNT(*) FROM Accounts WHERE NOT (income < 20000 OR income BETWEEN 20000 AND 50000) OR income IS NULL;
