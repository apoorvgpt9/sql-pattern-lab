-- breaks: edge_null_num
-- MISTAKE: PARTITION BY num puts every NULL in one partition, so three NULL rows in a row look like
-- an island of length 3 and NULL is reported. NULL = NULL is unknown: NULL never repeats.
WITH numbered AS (
  SELECT num,
         ROW_NUMBER() OVER (ORDER BY id)
         - ROW_NUMBER() OVER (PARTITION BY num ORDER BY id) AS island
  FROM Logs
),
runs AS (
  SELECT num, island, COUNT(*) AS run_length
  FROM numbered
  GROUP BY num, island
)
SELECT DISTINCT num AS ConsecutiveNums
FROM runs
WHERE run_length >= 3;
