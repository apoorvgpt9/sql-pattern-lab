-- breaks: edge_typical, edge_not_adjacent
-- MISTAKE: Counting how often a number appears at all. 'Appears three times' is not 'appears three times in a row'.
SELECT num AS ConsecutiveNums
FROM Logs
GROUP BY num
HAVING COUNT(*) >= 3;
