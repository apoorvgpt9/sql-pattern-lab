-- A day with two actions is removed entirely, and that splits the streak around it.
-- User 1 would have 6 days of 'view', but 2024-04-03 also has 'zoom', so that day is dropped:
-- 'view' becomes 04-01..04-02 (2 days) and 04-04..04-06 (3 days). 'zoom' sorts after 'view',
-- so keeping MIN(action) per day instead of dropping the day leaves a 6-day 'view' streak.
INSERT INTO activity (user_id, action_date, action) VALUES
  (1, '2024-04-01', 'view'), (1, '2024-04-02', 'view'),
  (1, '2024-04-03', 'view'), (1, '2024-04-03', 'zoom'),     -- two actions: the whole day is removed
  (1, '2024-04-04', 'view'), (1, '2024-04-05', 'view'), (1, '2024-04-06', 'view'),
  (2, '2024-04-01', 'view'), (2, '2024-04-02', 'view'), (2, '2024-04-03', 'view'),
  (2, '2024-04-04', 'view'), (2, '2024-04-05', 'view');

-- expect: 2,view,5,2024-04-01,2024-04-05 | 5 clean days; user 1's longest clean streak is 3
