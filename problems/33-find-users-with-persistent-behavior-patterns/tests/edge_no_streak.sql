-- No qualifying streak: user 1 has 9 consecutive days of 'x', but 07-05 also has 'y', so that day
-- is removed and the clean days form two 4-day streaks.
INSERT INTO activity (user_id, action_date, action) VALUES
  (1, '2024-07-01', 'x'), (1, '2024-07-02', 'x'), (1, '2024-07-03', 'x'), (1, '2024-07-04', 'x'),
  (1, '2024-07-05', 'x'), (1, '2024-07-05', 'y'),           -- two actions: day removed
  (1, '2024-07-06', 'x'), (1, '2024-07-07', 'x'), (1, '2024-07-08', 'x'), (1, '2024-07-09', 'x');

-- expect-empty: the clean 'x' streaks are 07-01..07-04 and 07-06..07-09, 4 days each
