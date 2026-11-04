-- breaks: edge_scroll_boundary
-- MISTAKE: grouping by user instead of session. User 7's two sessions merge into one 105-minute
-- "session" with 9 scrolls. The wording says per session; the user is an attribute of the session.
SELECT MIN(session_id) AS session_id, user_id,
       TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) AS session_duration_minutes,
       SUM(event_type = 'scroll') AS scroll_count
FROM app_events
GROUP BY user_id
HAVING TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) > 30
   AND SUM(event_type = 'scroll') >= 5
   AND SUM(event_type = 'click') / SUM(event_type = 'scroll') < 0.20
   AND SUM(event_type = 'purchase') = 0
ORDER BY scroll_count DESC, session_id;
