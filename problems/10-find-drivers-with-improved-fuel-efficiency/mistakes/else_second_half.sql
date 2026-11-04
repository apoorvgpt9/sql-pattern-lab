-- breaks: edge_nulls_and_zero_fuel
-- MISTAKE: CASE WHEN MONTH(...) <= 6 THEN first ELSE second. A NULL date makes the WHEN unknown, so the
-- trip falls into ELSE and is counted in the second half.
WITH t AS (
  SELECT driver_id,
         CASE WHEN MONTH(trip_date) <= 6 THEN 1 ELSE 2 END AS half,
         distance_km / NULLIF(fuel_consumed, 0) AS eff
  FROM trips
),
halves AS (
  SELECT driver_id, AVG(CASE WHEN half = 1 THEN eff END) AS f, AVG(CASE WHEN half = 2 THEN eff END) AS s
  FROM t GROUP BY driver_id
)
SELECT d.driver_id, d.driver_name, ROUND(h.f, 2) AS first_half_avg, ROUND(h.s, 2) AS second_half_avg,
       ROUND(h.s - h.f, 2) AS efficiency_improvement
FROM halves h JOIN drivers d ON d.driver_id = h.driver_id
WHERE h.s > h.f
ORDER BY efficiency_improvement DESC, d.driver_name ASC;
