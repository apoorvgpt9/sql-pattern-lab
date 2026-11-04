-- Approach 3 (optimal): one GROUP BY per session with conditional aggregation. Every metric is a
-- SUM over a boolean (MySQL: TRUE = 1) or a MIN/MAX in the same pass; all four rules go in HAVING.
SELECT session_id, user_id,
       TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) AS session_duration_minutes,
       SUM(event_type = 'scroll') AS scroll_count
FROM app_events
GROUP BY session_id, user_id
HAVING TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) > 30
   AND SUM(event_type = 'scroll') >= 5
   AND SUM(event_type = 'click') / SUM(event_type = 'scroll') < 0.20
   AND SUM(event_type = 'purchase') = 0
ORDER BY scroll_count DESC, session_id;
