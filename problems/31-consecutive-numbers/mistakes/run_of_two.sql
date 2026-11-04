-- breaks: edge_typical, edge_runs_of_two
-- MISTAKE: Looking only one row ahead: two equal neighbours are enough, so a run of 2 is reported as if it were a run of 3.
SELECT DISTINCT num AS ConsecutiveNums
FROM (
  SELECT num, LEAD(num, 1) OVER (ORDER BY id) AS next_num
  FROM Logs
) t
WHERE num = next_num;
