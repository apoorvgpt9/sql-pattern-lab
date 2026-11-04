-- Rounding to 2 decimals on exact decimal averages (MySQL AVG of INT is DECIMAL with 4 decimals).
-- User 1: eight trial days of 1,0,0,0,0,0,0,0 minutes: the mean is exactly 1/8 = 0.125, which must
-- round half UP to 0.13 (truncating gives 0.12). Zero-minute days are real rows and stay in the mean.
INSERT INTO UserActivity (user_id, activity_date, activity_type, activity_duration) VALUES
  (1, '2024-04-01', 'free_trial', 1),
  (1, '2024-04-02', 'free_trial', 0),
  (1, '2024-04-03', 'free_trial', 0),
  (1, '2024-04-04', 'free_trial', 0),
  (1, '2024-04-05', 'free_trial', 0),
  (1, '2024-04-06', 'free_trial', 0),
  (1, '2024-04-07', 'free_trial', 0),
  (1, '2024-04-08', 'free_trial', 0),
  (1, '2024-04-20', 'paid',       1),
  (1, '2024-04-21', 'paid',       1),
  (1, '2024-04-22', 'paid',       2),
  (2, '2024-05-01', 'free_trial', 10),
  (2, '2024-05-02', 'free_trial', 10),
  (2, '2024-05-03', 'free_trial', 11),
  (2, '2024-05-10', 'paid',       60);

-- expect: 1,0.13,1.33 | trial 1/8 = 0.125 -> 0.13 (half up); paid (1 + 1 + 2)/3 = 1.3333 -> 1.33
-- expect: 2,10.33,60.00 | trial (10 + 10 + 11)/3 = 31/3 = 10.3333 -> 10.33; paid 60
