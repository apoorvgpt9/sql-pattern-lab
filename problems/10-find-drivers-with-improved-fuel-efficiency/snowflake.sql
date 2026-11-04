-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9.
-- DIV0NULL would also work instead of NULLIF; plain x / 0 raises an error in Snowflake (it returns NULL in a MySQL SELECT).
WITH halves AS (
  SELECT
    driver_id,
    AVG(IFF(MONTH(trip_date) BETWEEN 1 AND 6,  distance_km / NULLIF(fuel_consumed, 0), NULL)) AS f,
    AVG(IFF(MONTH(trip_date) BETWEEN 7 AND 12, distance_km / NULLIF(fuel_consumed, 0), NULL)) AS s
  FROM trips
  GROUP BY driver_id
)
SELECT
  d.driver_id,
  d.driver_name,
  ROUND(h.f, 2)       AS first_half_avg,
  ROUND(h.s, 2)       AS second_half_avg,
  ROUND(h.s - h.f, 2) AS efficiency_improvement
FROM halves h
JOIN drivers d ON d.driver_id = h.driver_id
WHERE h.s > h.f
ORDER BY efficiency_improvement DESC, d.driver_name ASC;
