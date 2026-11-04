-- breaks: edge_independent_conditions
-- MISTAKE: filter to unique locations first, then look for tiv_2015 twins among the survivors. The tiv twin
-- of a qualifying policy may itself be disqualified by its location, and then the policy loses its twin.
WITH unique_loc AS (
  SELECT * FROM Insurance i
  WHERE NOT EXISTS (SELECT 1 FROM Insurance k WHERE k.lat = i.lat AND k.lon = i.lon AND k.pid <> i.pid)
)
SELECT ROUND(SUM(u.tiv_2016), 2) AS tiv_2016
FROM unique_loc u
WHERE EXISTS (SELECT 1 FROM unique_loc v WHERE v.tiv_2015 = u.tiv_2015 AND v.pid <> u.pid);
