-- Approach 1 (brute force): join each row to the row after it and the row after that, where "the next row"
-- is found with a subquery (the smallest id greater than this one). Keep the rows whose three values are equal.
-- Using the next EXISTING id, not id + 1, keeps it correct when ids have gaps (README Assumptions).
SELECT DISTINCT l1.num AS ConsecutiveNums
FROM Logs l1
JOIN Logs l2 ON l2.id = (SELECT MIN(x.id) FROM Logs x WHERE x.id > l1.id)
JOIN Logs l3 ON l3.id = (SELECT MIN(x.id) FROM Logs x WHERE x.id > l2.id)
WHERE l1.num = l2.num
  AND l2.num = l3.num;
