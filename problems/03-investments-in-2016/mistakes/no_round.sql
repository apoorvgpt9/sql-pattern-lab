-- breaks: edge_rounding
-- MISTAKE: forgetting the ROUND; the sum of FLOAT values comes back with float noise and extra decimals.
SELECT SUM(i.tiv_2016) AS tiv_2016
FROM Insurance i
WHERE EXISTS (SELECT 1 FROM Insurance j WHERE j.tiv_2015 = i.tiv_2015 AND j.pid <> i.pid)
  AND NOT EXISTS (SELECT 1 FROM Insurance k WHERE k.lat = i.lat AND k.lon = i.lon AND k.pid <> i.pid);
