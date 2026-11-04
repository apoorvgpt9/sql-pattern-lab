-- breaks: edge_duration_boundary
-- MISTAKE (against this repo's stated assumption): >= 30 minutes, as in the reference solution
-- this spec was drawn from. The requirement says more than 30; sessions of exactly 30 whole
-- minutes (30:00 and 30:59 both truncate to 30) are not zombies. See README "Assumptions".
SELECT session_id, user_id,
       TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) AS session_duration_minutes,
       SUM(event_type = 'scroll') AS scroll_count
FROM app_events
GROUP BY session_id, user_id
HAVING TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) >= 30 AND SUM(event_type = 'scroll') >= 5 AND SUM(event_type = 'click') / SUM(event_type = 'scroll') < 0.20 AND SUM(event_type = 'purchase') = 0
ORDER BY scroll_count DESC, session_id;
