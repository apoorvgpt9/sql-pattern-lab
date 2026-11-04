-- breaks: edge_nulls
-- MISTAKE: the window version without the `tiv_2015 IS NOT NULL` guard. PARTITION BY puts all NULLs in ONE
-- partition (NULLs are "not distinct" for grouping), so rows with NULL tiv_2015 look like twins of each other.
-- Equality-based versions (EXISTS, IN) treat NULL = NULL as unknown and disagree: that is the trap.
WITH counted AS (
  SELECT tiv_2016,
         COUNT(*) OVER (PARTITION BY tiv_2015)  AS n_same_tiv,
         COUNT(*) OVER (PARTITION BY lat, lon)  AS n_same_loc
  FROM Insurance
)
SELECT ROUND(SUM(tiv_2016), 2) AS tiv_2016 FROM counted WHERE n_same_tiv > 1 AND n_same_loc = 1;
