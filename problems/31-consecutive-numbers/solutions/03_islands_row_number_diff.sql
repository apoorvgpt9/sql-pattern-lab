-- Approach 3 (optimal): gaps-and-islands. Number all rows by id, and number the rows of each num by id.
-- Inside one run of equal values both numbers grow by 1 per row, so their DIFFERENCE is constant;
-- a different run of the same value has a different difference. Group by (num, difference) and keep groups of 3+.
-- Works for any run length N (change the HAVING). Only ROW_NUMBER windows are used: no look-ahead frame buffer.
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
