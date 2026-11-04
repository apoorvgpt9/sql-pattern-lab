-- breaks: edge_typical, edge_location_ties
-- MISTAKE: express "has a tiv twin" as a self-join. A policy with two twins produces two joined rows and its
-- tiv_2016 is summed twice (fan-out). EXISTS / IN / window counts are immune because they never multiply rows.
SELECT ROUND(SUM(i.tiv_2016), 2) AS tiv_2016
FROM Insurance i
JOIN Insurance j ON j.tiv_2015 = i.tiv_2015 AND j.pid <> i.pid
WHERE NOT EXISTS (SELECT 1 FROM Insurance k WHERE k.lat = i.lat AND k.lon = i.lon AND k.pid <> i.pid);
