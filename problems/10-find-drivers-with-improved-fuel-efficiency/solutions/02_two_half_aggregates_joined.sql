-- Approach 2: one grouped query per half (each yields one row per driver), joined on driver_id.
-- Two scans of trips instead of two per driver. The inner joins are right here: a driver needs BOTH halves,
-- and a half whose only trips have undefined efficiency has AVG = NULL, so the s > f comparison drops it.
WITH first_half AS (
  SELECT driver_id, AVG(distance_km / NULLIF(fuel_consumed, 0)) AS avg_eff
  FROM trips
  WHERE MONTH(trip_date) BETWEEN 1 AND 6
  GROUP BY driver_id
),
second_half AS (
  SELECT driver_id, AVG(distance_km / NULLIF(fuel_consumed, 0)) AS avg_eff
  FROM trips
  WHERE MONTH(trip_date) BETWEEN 7 AND 12
  GROUP BY driver_id
)
SELECT
  d.driver_id,
  d.driver_name,
  ROUND(f.avg_eff, 2)               AS first_half_avg,
  ROUND(s.avg_eff, 2)               AS second_half_avg,
  ROUND(s.avg_eff - f.avg_eff, 2)   AS efficiency_improvement
FROM drivers d
JOIN first_half  f ON f.driver_id = d.driver_id
JOIN second_half s ON s.driver_id = d.driver_id
WHERE s.avg_eff > f.avg_eff
ORDER BY efficiency_improvement DESC, d.driver_name ASC;
