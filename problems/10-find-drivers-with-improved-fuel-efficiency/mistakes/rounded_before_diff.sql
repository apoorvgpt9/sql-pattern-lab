-- breaks: edge_rounding_trap
-- MISTAKE: subtract the two ROUNDED averages. The spec takes the difference of the unrounded values and
-- rounds once; here 13.33 - 11.24 = 2.09 where the correct answer is 2.10.
WITH halves AS (
  SELECT driver_id,
         ROUND(AVG(CASE WHEN MONTH(trip_date) BETWEEN 1 AND 6  THEN distance_km / NULLIF(fuel_consumed, 0) END), 2) AS f,
         ROUND(AVG(CASE WHEN MONTH(trip_date) BETWEEN 7 AND 12 THEN distance_km / NULLIF(fuel_consumed, 0) END), 2) AS s
  FROM trips GROUP BY driver_id
)
SELECT d.driver_id, d.driver_name, h.f AS first_half_avg, h.s AS second_half_avg,
       ROUND(h.s - h.f, 2) AS efficiency_improvement
FROM halves h JOIN drivers d ON d.driver_id = h.driver_id
WHERE h.s > h.f
ORDER BY efficiency_improvement DESC, d.driver_name ASC;
