-- breaks: edge_rounding_trap
-- MISTAKE: compare the rounded averages in the filter. A real (tiny) improvement that rounds to the
-- same 2-decimal number is thrown away, although the second-half mean does exceed the first.
WITH halves AS (
  SELECT driver_id,
         AVG(CASE WHEN MONTH(trip_date) BETWEEN 1 AND 6  THEN distance_km / NULLIF(fuel_consumed, 0) END) AS f,
         AVG(CASE WHEN MONTH(trip_date) BETWEEN 7 AND 12 THEN distance_km / NULLIF(fuel_consumed, 0) END) AS s
  FROM trips GROUP BY driver_id
)
SELECT d.driver_id, d.driver_name, ROUND(h.f, 2) AS first_half_avg, ROUND(h.s, 2) AS second_half_avg,
       ROUND(h.s - h.f, 2) AS efficiency_improvement
FROM halves h JOIN drivers d ON d.driver_id = h.driver_id
WHERE ROUND(h.s, 2) > ROUND(h.f, 2)
ORDER BY efficiency_improvement DESC, d.driver_name ASC;
