-- breaks: edge_long_runs_repeat
-- MISTAKE: The set semantics: without DISTINCT, a run of 5 yields three qualifying rows and a number with two runs is listed twice.
SELECT num AS ConsecutiveNums
FROM (
  SELECT num, LEAD(num, 1) OVER w AS next_num, LEAD(num, 2) OVER w AS next_next_num
  FROM Logs
  WINDOW w AS (ORDER BY id)
) t
WHERE num = next_num AND num = next_next_num;
