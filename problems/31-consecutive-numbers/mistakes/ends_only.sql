-- breaks: edge_not_adjacent
-- MISTAKE: Comparing the first and third rows of the triple and forgetting the middle one: x y x passes.
SELECT DISTINCT num AS ConsecutiveNums
FROM (
  SELECT num, LEAD(num, 2) OVER (ORDER BY id) AS next_next_num
  FROM Logs
) t
WHERE num = next_next_num;
