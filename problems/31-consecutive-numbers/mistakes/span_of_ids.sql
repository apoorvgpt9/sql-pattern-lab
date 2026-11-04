-- breaks: edge_typical, edge_not_adjacent
-- MISTAKE: Using the span between a number's first and last id as the run length. A number can span 3+ ids with other values in between.
SELECT num AS ConsecutiveNums
FROM Logs
GROUP BY num
HAVING MAX(id) - MIN(id) + 1 >= 3;
