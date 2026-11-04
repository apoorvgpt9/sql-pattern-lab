-- Approach 2: one ordered pass; each row looks at the next two rows with LEAD (the shortest query for a fixed length of 3).
-- A row that starts a run of three has the same value in all three positions. DISTINCT collapses longer runs
-- (which produce several such rows) and repeated runs of the same number.
-- MySQL needs a frame buffer to look ahead (EXPLAIN: "Window aggregate with buffering").
SELECT DISTINCT num AS ConsecutiveNums
FROM (
  SELECT num,
         LEAD(num, 1) OVER w AS next_num,
         LEAD(num, 2) OVER w AS next_next_num
  FROM Logs
  WINDOW w AS (ORDER BY id)
) t
WHERE num = next_num
  AND num = next_next_num;
