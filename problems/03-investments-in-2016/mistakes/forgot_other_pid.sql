-- breaks: edge_typical, edge_none_qualify
-- MISTAKE: "shares tiv_2015 with at least one other" tested without `pid <> i.pid`. Every policy matches
-- itself, so the tiv condition is always true and unique-tiv policies leak in.
SELECT ROUND(SUM(i.tiv_2016), 2) AS tiv_2016
FROM Insurance i
WHERE EXISTS (SELECT 1 FROM Insurance j WHERE j.tiv_2015 = i.tiv_2015)
  AND NOT EXISTS (SELECT 1 FROM Insurance k WHERE k.lat = i.lat AND k.lon = i.lon AND k.pid <> i.pid);
