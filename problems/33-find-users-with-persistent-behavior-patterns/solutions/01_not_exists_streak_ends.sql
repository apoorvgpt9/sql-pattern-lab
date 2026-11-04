-- Approach 1 (brute force): no window functions. Build streaks from their ends.
--   clean   : rows whose (user, day) has no other action (NOT EXISTS).
--   starts  : clean days with no same-action clean day the day before.
--   streaks : for each start, the first clean day on/after it whose next day is missing = the end.
--   keep    : streaks of >= 5 days with no better streak for the same user
--             (longer, or equally long and starting earlier - see README "Assumptions").
-- Natural first attempt for someone thinking "a streak starts where yesterday is missing".
WITH clean AS (
  SELECT a.user_id, a.action_date, a.action
  FROM activity a
  WHERE NOT EXISTS (SELECT 1 FROM activity o
                    WHERE o.user_id = a.user_id
                      AND o.action_date = a.action_date
                      AND o.action <> a.action)
),
starts AS (
  SELECT c.user_id, c.action, c.action_date AS start_date
  FROM clean c
  WHERE NOT EXISTS (SELECT 1 FROM clean p
                    WHERE p.user_id = c.user_id AND p.action = c.action
                      AND p.action_date = c.action_date - INTERVAL 1 DAY)
),
streaks AS (
  SELECT s.user_id, s.action, s.start_date,
         (SELECT MIN(e.action_date)
            FROM clean e
           WHERE e.user_id = s.user_id AND e.action = s.action
             AND e.action_date >= s.start_date
             AND NOT EXISTS (SELECT 1 FROM clean n
                             WHERE n.user_id = e.user_id AND n.action = e.action
                               AND n.action_date = e.action_date + INTERVAL 1 DAY)) AS end_date
  FROM starts s
),
long_streaks AS (
  SELECT user_id, action, start_date, end_date,
         DATEDIFF(end_date, start_date) + 1 AS streak_length
  FROM streaks
  WHERE DATEDIFF(end_date, start_date) + 1 >= 5
)
SELECT l.user_id, l.action, l.streak_length, l.start_date, l.end_date
FROM long_streaks l
WHERE NOT EXISTS (SELECT 1 FROM long_streaks b
                  WHERE b.user_id = l.user_id
                    AND (b.streak_length > l.streak_length
                         OR (b.streak_length = l.streak_length AND b.start_date < l.start_date)))
ORDER BY l.streak_length DESC, l.user_id;
