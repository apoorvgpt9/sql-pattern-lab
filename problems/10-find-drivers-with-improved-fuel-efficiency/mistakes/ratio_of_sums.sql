-- breaks: edge_typical
-- MISTAKE: efficiency of a half = total distance / total fuel. The spec averages the PER-TRIP ratios
-- (the trigger phrase "for each trip"). A long, thirsty trip dominates the ratio of sums but counts once in the mean.
WITH halves AS (
  SELECT driver_id,
         SUM(CASE WHEN MONTH(trip_date) BETWEEN 1 AND 6  THEN distance_km END)
           / NULLIF(SUM(CASE WHEN MONTH(trip_date) BETWEEN 1 AND 6  THEN fuel_consumed END), 0) AS f,
         SUM(CASE WHEN MONTH(trip_date) BETWEEN 7 AND 12 THEN distance_km END)
           / NULLIF(SUM(CASE WHEN MONTH(trip_date) BETWEEN 7 AND 12 THEN fuel_consumed END), 0) AS s
  FROM trips GROUP BY driver_id
)
SELECT d.driver_id, d.driver_name, ROUND(h.f, 2) AS first_half_avg, ROUND(h.s, 2) AS second_half_avg,
       ROUND(h.s - h.f, 2) AS efficiency_improvement
FROM halves h JOIN drivers d ON d.driver_id = h.driver_id
WHERE h.s > h.f
ORDER BY efficiency_improvement DESC, d.driver_name ASC;
