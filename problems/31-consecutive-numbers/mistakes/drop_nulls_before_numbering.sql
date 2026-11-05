-- breaks: edge_null_num
-- MISTAKE: removing NULL rows before the global ROW_NUMBER closes the gap they leave, so the rows on
-- either side of a NULL look adjacent ('7', NULL, '7', '7' becomes a run of three 7s).
WITH numbered AS (
  SELECT num,
         ROW_NUMBER() OVER (ORDER BY id)
         - ROW_NUMBER() OVER (PARTITION BY num ORDER BY id) AS island
  FROM Logs
  WHERE num IS NOT NULL
),
runs AS (
  SELECT num, island, COUNT(*) AS run_length
  FROM numbered
  GROUP BY num, island
)
SELECT DISTINCT num AS ConsecutiveNums
FROM runs
WHERE run_length >= 3;
