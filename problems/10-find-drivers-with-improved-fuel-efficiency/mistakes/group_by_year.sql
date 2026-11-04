-- breaks: edge_half_boundaries
-- MISTAKE: grouping by (driver, year) "to be careful about years". The spec buckets by month only, so
-- the same half in different years is one bucket. Per-year groups put Jon's trips in three separate
-- years, none of which has both halves.
WITH halves AS (
  SELECT driver_id, YEAR(trip_date) AS yr,
         AVG(CASE WHEN MONTH(trip_date) BETWEEN 1 AND 6  THEN distance_km / NULLIF(fuel_consumed, 0) END) AS f,
         AVG(CASE WHEN MONTH(trip_date) BETWEEN 7 AND 12 THEN distance_km / NULLIF(fuel_consumed, 0) END) AS s
  FROM trips GROUP BY driver_id, YEAR(trip_date)
)
SELECT d.driver_id, d.driver_name, ROUND(h.f, 2) AS first_half_avg, ROUND(h.s, 2) AS second_half_avg,
       ROUND(h.s - h.f, 2) AS efficiency_improvement
FROM halves h JOIN drivers d ON d.driver_id = h.driver_id
WHERE h.s > h.f
ORDER BY efficiency_improvement DESC, d.driver_name ASC;
