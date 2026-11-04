-- Approach 2: attach both counts to every row in one pass with window functions, then filter.
-- tiv_2015 IS NOT NULL: PARTITION BY puts all NULLs in one partition, but NULL is not a "shared value".
WITH counted AS (
  SELECT tiv_2015, tiv_2016,
         COUNT(*) OVER (PARTITION BY tiv_2015)  AS n_same_tiv,
         COUNT(*) OVER (PARTITION BY lat, lon)  AS n_same_loc
  FROM Insurance
)
SELECT ROUND(SUM(tiv_2016), 2) AS tiv_2016
FROM counted
WHERE tiv_2015 IS NOT NULL
  AND n_same_tiv > 1
  AND n_same_loc = 1;
