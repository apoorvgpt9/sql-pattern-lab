-- breaks: edge_nulls_and_zero_fuel
-- MISTAKE: COALESCE(distance_km / fuel, 0) per trip. A trip whose efficiency is undefined is not a trip
-- with efficiency 0: it drags the half's mean toward zero (Oro's first half becomes AVG(6, 0) = 3).
WITH t AS (
  SELECT driver_id,
         CASE WHEN MONTH(trip_date) BETWEEN 1 AND 6 THEN 1 WHEN MONTH(trip_date) BETWEEN 7 AND 12 THEN 2 END AS half,
         COALESCE(distance_km / NULLIF(fuel_consumed, 0), 0) AS eff
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
