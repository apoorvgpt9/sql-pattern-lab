-- breaks: edge_location_ties
-- MISTAKE: "unique city" checked on lat alone. Two policies that share a latitude but not a longitude are in
-- different places; this drops pid 3 of the dataset.
SELECT ROUND(SUM(tiv_2016), 2) AS tiv_2016
FROM Insurance
WHERE tiv_2015 IN (SELECT tiv_2015 FROM Insurance GROUP BY tiv_2015 HAVING COUNT(*) > 1)
  AND lat IN (SELECT lat FROM Insurance GROUP BY lat HAVING COUNT(*) = 1);
