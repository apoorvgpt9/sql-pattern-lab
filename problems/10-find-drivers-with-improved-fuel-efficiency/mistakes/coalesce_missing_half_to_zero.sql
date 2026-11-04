-- breaks: edge_typical, edge_nulls_and_zero_fuel, edge_none_improved
-- MISTAKE: COALESCE(avg, 0) "so the subtraction never sees a NULL". A driver with a trip in only the second
-- half is then compared against 0 and appears as hugely improved; "trips in both halves" is lost.
WITH halves AS (
  SELECT driver_id,
         COALESCE(AVG(CASE WHEN MONTH(trip_date) BETWEEN 1 AND 6  THEN distance_km / NULLIF(fuel_consumed, 0) END), 0) AS f,
         COALESCE(AVG(CASE WHEN MONTH(trip_date) BETWEEN 7 AND 12 THEN distance_km / NULLIF(fuel_consumed, 0) END), 0) AS s
  FROM trips GROUP BY driver_id
)
SELECT d.driver_id, d.driver_name, ROUND(h.f, 2) AS first_half_avg, ROUND(h.s, 2) AS second_half_avg,
       ROUND(h.s - h.f, 2) AS efficiency_improvement
FROM halves h JOIN drivers d ON d.driver_id = h.driver_id
WHERE h.s > h.f
ORDER BY efficiency_improvement DESC, d.driver_name ASC;
