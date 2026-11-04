-- breaks: edge_typical
-- MISTAKE: filtering to the "interesting" event types in WHERE before grouping. app_open and
-- app_close are part of the session, so dropping them shortens the duration (a1: 25 min instead of 40).
SELECT session_id, user_id,
       TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) AS session_duration_minutes,
       SUM(event_type = 'scroll') AS scroll_count
FROM app_events
WHERE event_type IN ('scroll', 'click', 'purchase')
GROUP BY session_id, user_id
HAVING TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) > 30
   AND SUM(event_type = 'scroll') >= 5
   AND SUM(event_type = 'click') / SUM(event_type = 'scroll') < 0.20
   AND SUM(event_type = 'purchase') = 0
ORDER BY scroll_count DESC, session_id;
