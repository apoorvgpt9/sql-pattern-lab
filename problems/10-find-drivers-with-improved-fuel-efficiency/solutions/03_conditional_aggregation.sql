-- Approach 3 (optimal): compute each trip's efficiency and half once, pivot the halves into two columns
-- with one GROUP BY driver_id, then filter, join the name and round.
-- AVG(CASE ...) ignores the NULLs the CASE produces for the other half, so each column is the mean of its
-- own half only. A NULL month (NULL date) matches neither WHEN, so that trip is in neither half.
WITH trip_eff AS (
  SELECT
    driver_id,
    CASE WHEN MONTH(trip_date) BETWEEN 1 AND 6  THEN 1
         WHEN MONTH(trip_date) BETWEEN 7 AND 12 THEN 2 END AS half,
    distance_km / NULLIF(fuel_consumed, 0)                 AS eff
  FROM trips
),
halves AS (
  SELECT
    driver_id,
    AVG(CASE WHEN half = 1 THEN eff END) AS f,
    AVG(CASE WHEN half = 2 THEN eff END) AS s
  FROM trip_eff
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
WHERE h.s > h.f            -- unknown (dropped) unless both halves have a mean
ORDER BY efficiency_improvement DESC, d.driver_name ASC;
