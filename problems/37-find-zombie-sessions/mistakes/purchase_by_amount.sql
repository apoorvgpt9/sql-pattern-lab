-- breaks: edge_nulls, edge_none_qualify
-- MISTAKE: 'no purchases' tested through the purchase amount (no revenue). A purchase whose
-- event_value is NULL or 0 adds no revenue but is still a purchase event.
SELECT session_id, user_id,
       TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) AS session_duration_minutes,
       SUM(event_type = 'scroll') AS scroll_count
FROM app_events
GROUP BY session_id, user_id
HAVING TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) > 30 AND SUM(event_type = 'scroll') >= 5 AND SUM(event_type = 'click') / SUM(event_type = 'scroll') < 0.20 AND COALESCE(SUM(CASE WHEN event_type = 'purchase' THEN event_value END), 0) = 0
ORDER BY scroll_count DESC, session_id;
