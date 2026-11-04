-- Typical: three users, one clean streak each. Streaks of 6 and 5 qualify; 4 does not.
INSERT INTO activity (user_id, action_date, action) VALUES
  (1, '2024-01-01', 'login'), (1, '2024-01-02', 'login'), (1, '2024-01-03', 'login'),
  (1, '2024-01-04', 'login'), (1, '2024-01-05', 'login'), (1, '2024-01-06', 'login'),
  (2, '2024-01-01', 'post'),  (2, '2024-01-02', 'post'),  (2, '2024-01-03', 'post'),
  (2, '2024-01-04', 'post'),                                -- user 2: 4 days, one short
  (3, '2024-01-10', 'like'),  (3, '2024-01-11', 'like'),  (3, '2024-01-12', 'like'),
  (3, '2024-01-13', 'like'),  (3, '2024-01-14', 'like');

-- expect: 1,login,6,2024-01-01,2024-01-06 | 6 consecutive single-action days; longest streak first in the order
-- expect: 3,like,5,2024-01-10,2024-01-14 | exactly 5 days qualifies (>= 5); user 2 has only 4
