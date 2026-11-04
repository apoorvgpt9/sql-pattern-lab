-- breaks: edge_half_boundaries
-- MISTAKE: first half written as MONTH < 6 (January-May). June trips fall through to the second half.
WITH halves AS (
  SELECT driver_id,
         AVG(CASE WHEN MONTH(trip_date) < 6  THEN distance_km / NULLIF(fuel_consumed, 0) END) AS f,
         AVG(CASE WHEN MONTH(trip_date) >= 6 THEN distance_km / NULLIF(fuel_consumed, 0) END) AS s
  FROM trips GROUP BY driver_id
)
SELECT d.driver_id, d.driver_name, ROUND(h.f, 2) AS first_half_avg, ROUND(h.s, 2) AS second_half_avg,
       ROUND(h.s - h.f, 2) AS efficiency_improvement
FROM halves h JOIN drivers d ON d.driver_id = h.driver_id
WHERE h.s > h.f
ORDER BY efficiency_improvement DESC, d.driver_name ASC;
