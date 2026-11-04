-- breaks: edge_location_ties
-- MISTAKE: the same, on longitude alone; drops pid 4 of the dataset.
SELECT ROUND(SUM(tiv_2016), 2) AS tiv_2016
FROM Insurance
WHERE tiv_2015 IN (SELECT tiv_2015 FROM Insurance GROUP BY tiv_2015 HAVING COUNT(*) > 1)
  AND lon IN (SELECT lon FROM Insurance GROUP BY lon HAVING COUNT(*) = 1);
