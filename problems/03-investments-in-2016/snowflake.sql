-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9.
SELECT ROUND(SUM(i.tiv_2016), 2) AS tiv_2016
FROM Insurance i
WHERE EXISTS (SELECT 1 FROM Insurance j
              WHERE j.tiv_2015 = i.tiv_2015 AND j.pid <> i.pid)
  AND NOT EXISTS (SELECT 1 FROM Insurance k
                  WHERE k.lat = i.lat AND k.lon = i.lon AND k.pid <> i.pid);

-- Alternative worth benchmarking in Snowflake (approach 2): one pass, two window counts, no self-join.
-- WITH counted AS (
--   SELECT tiv_2015, tiv_2016,
--          COUNT(*) OVER (PARTITION BY tiv_2015) AS n_same_tiv,
--          COUNT(*) OVER (PARTITION BY lat, lon) AS n_same_loc
--   FROM Insurance
-- )
-- SELECT ROUND(SUM(tiv_2016), 2) AS tiv_2016
-- FROM counted
-- WHERE tiv_2015 IS NOT NULL AND n_same_tiv > 1 AND n_same_loc = 1;
