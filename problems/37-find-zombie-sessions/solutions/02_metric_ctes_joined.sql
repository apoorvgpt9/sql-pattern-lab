-- Approach 2: one pass per metric, then join. Each CTE answers one question with a WHERE filter
-- on event_type; LEFT JOIN keeps sessions with zero clicks; NOT EXISTS removes buyers.
WITH durations AS (
  SELECT session_id, user_id,
         TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) AS duration_min
  FROM app_events
  GROUP BY session_id, user_id
),
scrolls AS (
  SELECT session_id, COUNT(*) AS n FROM app_events WHERE event_type = 'scroll' GROUP BY session_id
),
clicks AS (
  SELECT session_id, COUNT(*) AS n FROM app_events WHERE event_type = 'click' GROUP BY session_id
)
SELECT d.session_id, d.user_id,
       d.duration_min AS session_duration_minutes,
       s.n            AS scroll_count
FROM durations d
JOIN scrolls s      ON s.session_id = d.session_id
LEFT JOIN clicks c  ON c.session_id = d.session_id
WHERE d.duration_min > 30
  AND s.n >= 5
  AND COALESCE(c.n, 0) / s.n < 0.20
  AND NOT EXISTS (SELECT 1 FROM app_events p
                  WHERE p.session_id = d.session_id AND p.event_type = 'purchase')
ORDER BY scroll_count DESC, d.session_id;
