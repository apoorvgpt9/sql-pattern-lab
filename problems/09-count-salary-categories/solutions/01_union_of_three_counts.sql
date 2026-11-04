-- Approach 1 (brute force): one COUNT(*) query per category, glued with UNION ALL.
-- Natural first attempt: the spec lists three categories, so write three queries.
-- An aggregate without GROUP BY always returns exactly one row, 0 on an empty input, so the
-- "must appear with 0" rule holds without a scaffold. The price is three scans of Accounts.
SELECT 'Low Salary' AS category, COUNT(*) AS accounts_count
FROM Accounts WHERE income < 20000
UNION ALL
SELECT 'Average Salary', COUNT(*)
FROM Accounts WHERE income BETWEEN 20000 AND 50000
UNION ALL
SELECT 'High Salary', COUNT(*)
FROM Accounts WHERE income > 50000;
