-- Streaks that cross a year boundary and the end of a non-leap February, plus a 4-day streak.
-- Both 5-day streaks tie on streak_length, so user_id ASC decides their order.
INSERT INTO activity (user_id, action_date, action) VALUES
  (1, '2023-12-30', 'gym'), (1, '2023-12-31', 'gym'), (1, '2024-01-01', 'gym'),
  (1, '2024-01-02', 'gym'), (1, '2024-01-03', 'gym'),       -- crosses the new year
  (2, '2024-06-01', 'gym'), (2, '2024-06-02', 'gym'), (2, '2024-06-03', 'gym'),
  (2, '2024-06-04', 'gym'),                                 -- 4 days: one short of the threshold
  (3, '2023-02-27', 'gym'), (3, '2023-02-28', 'gym'), (3, '2023-03-01', 'gym'),
  (3, '2023-03-02', 'gym'), (3, '2023-03-03', 'gym');       -- 2023 is not a leap year: 02-28 -> 03-01

-- expect: 1,gym,5,2023-12-30,2024-01-03 | 12-30, 12-31, 01-01, 01-02, 01-03 are consecutive days; ties with user 3 on length, lower user_id first
-- expect: 3,gym,5,2023-02-27,2023-03-03 | 02-27, 02-28, 03-01, 03-02, 03-03 are consecutive days in 2023
