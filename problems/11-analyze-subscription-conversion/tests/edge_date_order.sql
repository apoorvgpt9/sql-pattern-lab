-- The spec asks only that a user has BOTH kinds of rows; it never compares dates (see README Assumptions).
-- So paid-before-trial, trial and paid on the same day, and a cancelled row in between all still count.
INSERT INTO UserActivity (user_id, activity_date, activity_type, activity_duration) VALUES
  (1, '2024-01-01', 'paid',       50),   -- user 1: paid BEFORE the trial
  (1, '2024-02-01', 'free_trial', 20),
  (2, '2024-03-01', 'free_trial', 10),   -- user 2: trial and paid on the same day (types differ, so the key is unique)
  (2, '2024-03-01', 'paid',       30),
  (3, '2024-03-01', 'free_trial',  5),   -- user 3: trial, cancelled, then paid
  (3, '2024-03-05', 'cancelled', 999),
  (3, '2024-03-10', 'paid',       15);

-- expect: 1,20.00,50.00 | both types exist; the paid row being earlier does not matter
-- expect: 2,10.00,30.00 | same-day trial and paid both count
-- expect: 3,5.00,15.00 | the cancelled row between them is ignored
