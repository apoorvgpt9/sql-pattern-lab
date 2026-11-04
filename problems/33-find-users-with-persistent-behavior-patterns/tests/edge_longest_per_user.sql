-- One user with two qualifying streaks of the same action (5 days, then 7 days after a one-day gap).
-- Only the longest one is reported, and it is not the first one.
INSERT INTO activity (user_id, action_date, action) VALUES
  (1, '2024-03-01', 'read'), (1, '2024-03-02', 'read'), (1, '2024-03-03', 'read'),
  (1, '2024-03-04', 'read'), (1, '2024-03-05', 'read'),       -- streak A: 5 days
                                                              -- 03-06: no activity, streak breaks
  (1, '2024-03-07', 'read'), (1, '2024-03-08', 'read'), (1, '2024-03-09', 'read'),
  (1, '2024-03-10', 'read'), (1, '2024-03-11', 'read'), (1, '2024-03-12', 'read'),
  (1, '2024-03-13', 'read'),                                  -- streak B: 7 days
  (2, '2024-03-01', 'read'), (2, '2024-03-02', 'read'), (2, '2024-03-03', 'read');

-- expect: 1,read,7,2024-03-07,2024-03-13 | streak B (7) beats streak A (5); one row per user
