-- Approach 1 (brute force): list the sessions, then compute each metric with its own correlated
-- subquery. One subquery per sentence of the spec: duration, scrolls, clicks, purchases.
WITH sessions AS (
  SELECT DISTINCT session_id, user_id FROM app_events
),
metrics AS (
  SELECT s.session_id, s.user_id,
         (SELECT TIMESTAMPDIFF(MINUTE, MIN(a.event_timestamp), MAX(a.event_timestamp))
            FROM app_events a WHERE a.session_id = s.session_id) AS duration_min,
         (SELECT COUNT(*) FROM app_events a
           WHERE a.session_id = s.session_id AND a.event_type = 'scroll') AS scrolls,
         (SELECT COUNT(*) FROM app_events a
           WHERE a.session_id = s.session_id AND a.event_type = 'click') AS clicks,
         (SELECT COUNT(*) FROM app_events a
           WHERE a.session_id = s.session_id AND a.event_type = 'purchase') AS purchases
  FROM sessions s
)
SELECT session_id, user_id,
       duration_min AS session_duration_minutes,
       scrolls      AS scroll_count
FROM metrics
WHERE duration_min > 30
  AND scrolls >= 5
  AND clicks / scrolls < 0.20
  AND purchases = 0
ORDER BY scroll_count DESC, session_id;
