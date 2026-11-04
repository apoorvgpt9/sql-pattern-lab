-- breaks: edge_duration_boundary
-- MISTAKE: measuring duration in fractional minutes (seconds / 60). 30 min 59 s is 30.98 > 30, but the
-- spec counts whole minutes: TIMESTAMPDIFF(MINUTE, ...) truncates it to 30.
SELECT session_id, user_id,
       TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) AS session_duration_minutes,
       SUM(event_type = 'scroll') AS scroll_count
FROM app_events
GROUP BY session_id, user_id
HAVING (UNIX_TIMESTAMP(MAX(event_timestamp)) - UNIX_TIMESTAMP(MIN(event_timestamp))) / 60 > 30 AND SUM(event_type = 'scroll') >= 5 AND SUM(event_type = 'click') / SUM(event_type = 'scroll') < 0.20 AND SUM(event_type = 'purchase') = 0
ORDER BY scroll_count DESC, session_id;
