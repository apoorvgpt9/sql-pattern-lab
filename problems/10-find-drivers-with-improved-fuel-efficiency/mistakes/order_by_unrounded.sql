-- breaks: edge_ordering
-- MISTAKE: sorting on the unrounded difference. The spec sorts on the reported efficiency_improvement
-- (2 decimals); two drivers showing 1.00 must then be ordered by name, not by hidden decimals.
WITH halves AS (
  SELECT driver_id,
         AVG(CASE WHEN MONTH(trip_date) BETWEEN 1 AND 6  THEN distance_km / NULLIF(fuel_consumed, 0) END) AS f,
         AVG(CASE WHEN MONTH(trip_date) BETWEEN 7 AND 12 THEN distance_km / NULLIF(fuel_consumed, 0) END) AS s
  FROM trips GROUP BY driver_id
)
SELECT d.driver_id, d.driver_name, ROUND(h.f, 2) AS first_half_avg, ROUND(h.s, 2) AS second_half_avg,
       ROUND(h.s - h.f, 2) AS efficiency_improvement
FROM halves h JOIN drivers d ON d.driver_id = h.driver_id
WHERE h.s > h.f
ORDER BY (h.s - h.f) DESC, d.driver_name ASC;
