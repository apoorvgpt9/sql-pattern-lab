-- Approach 1 (brute force): for each driver, ask two scalar questions - "average efficiency in Jan-Jun",
-- "average efficiency in Jul-Dec" - then keep the drivers where the second answer is larger.
-- AVG skips NULL ratios (zero/NULL fuel, NULL distance), and returns NULL when a half has no usable trip,
-- so "s > f" is unknown (and the driver dropped) unless BOTH halves have a mean.
-- Rounding happens once, in the outer SELECT, on the unrounded averages.
SELECT
  x.driver_id,
  x.driver_name,
  ROUND(x.f, 2)       AS first_half_avg,
  ROUND(x.s, 2)       AS second_half_avg,
  ROUND(x.s - x.f, 2) AS efficiency_improvement
FROM (
  SELECT
    d.driver_id,
    d.driver_name,
    (SELECT AVG(t.distance_km / NULLIF(t.fuel_consumed, 0)) FROM trips t
      WHERE t.driver_id = d.driver_id AND MONTH(t.trip_date) BETWEEN 1 AND 6)  AS f,
    (SELECT AVG(t.distance_km / NULLIF(t.fuel_consumed, 0)) FROM trips t
      WHERE t.driver_id = d.driver_id AND MONTH(t.trip_date) BETWEEN 7 AND 12) AS s
  FROM drivers d
) x
WHERE x.s > x.f
ORDER BY efficiency_improvement DESC, x.driver_name ASC;
