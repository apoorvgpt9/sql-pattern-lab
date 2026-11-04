-- ASSUMPTION test (README "Assumptions"): one user has two longest streaks of equal length.
-- The spec does not say which to report; this repo reports the one that starts first.
-- The earlier streak has the alphabetically LATER action, so "tie-break by action" gives a different answer.
INSERT INTO activity (user_id, action_date, action) VALUES
  (1, '2024-06-01', 'test'), (1, '2024-06-02', 'test'), (1, '2024-06-03', 'test'),
  (1, '2024-06-04', 'test'), (1, '2024-06-05', 'test'),     -- 5 days, starts first
  (1, '2024-06-10', 'code'), (1, '2024-06-11', 'code'), (1, '2024-06-12', 'code'),
  (1, '2024-06-13', 'code'), (1, '2024-06-14', 'code');     -- 5 days, starts later

-- expect: 1,test,5,2024-06-01,2024-06-05 | both streaks are 5 days; the earlier start date wins the tie
