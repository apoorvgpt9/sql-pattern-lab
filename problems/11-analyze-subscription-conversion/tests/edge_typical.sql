-- Typical mix: converted users, a trial-only user, a paid-only user, a user with cancelled rows
-- among their trial and paid rows, and a cancelled-only user.
INSERT INTO UserActivity (user_id, activity_date, activity_type, activity_duration) VALUES
  (1, '2024-01-01', 'free_trial', 10),
  (1, '2024-01-02', 'free_trial', 15),
  (1, '2024-01-10', 'paid',       30),
  (2, '2024-01-01', 'free_trial',  5),   -- trial only: never converted
  (3, '2024-01-05', 'paid',       50),   -- paid only: no trial row
  (4, '2024-02-01', 'free_trial',  7),
  (4, '2024-02-02', 'free_trial',  8),
  (4, '2024-02-03', 'free_trial',  8),
  (4, '2024-02-10', 'paid',       40),
  (4, '2024-02-11', 'paid',       41),
  (4, '2024-02-20', 'cancelled', 999),   -- ignored: must not feed either average
  (5, '2024-03-01', 'cancelled',  20);   -- cancelled only

-- expect: 1,12.50,30.00 | trial AVG(10, 15) = 12.5; paid AVG(30) = 30
-- expect: 4,7.67,40.50 | trial AVG(7, 8, 8) = 23/3 = 7.6667 -> 7.67; paid AVG(40, 41) = 40.5; the cancelled 999 is ignored
-- (user 2 has no paid row, user 3 no trial row, user 5 neither)
