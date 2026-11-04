-- The sum has more than two decimals and must be rounded. 12.345678 is stored as the nearest FLOAT
-- (12.3456783...), which rounds to 12.35 at 2 decimals; a zero tiv_2016 is a real value, not NULL.
INSERT INTO Insurance (pid, tiv_2015, tiv_2016, lat, lon) VALUES
  (1, 5.0, 12.345678, 1.0, 1.0),
  (2, 5.0, 0.0,       2.0, 2.0);

-- expect: 12.35 | 12.345678 + 0 = 12.345678, rounded to 2 decimals (the third decimal is 5 followed by 678: round up)
