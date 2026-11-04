-- breaks: edge_ratio_boundary
-- MISTAKE: dividing clicks by ALL events instead of by scrolls. The denominator is named in the
-- wording (click-to-scroll); with 1 click, 5 scrolls and nothing else, 1/6 = 0.1667 slips under 0.20.
SELECT session_id, user_id,
       TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) AS session_duration_minutes,
       SUM(event_type = 'scroll') AS scroll_count
FROM app_events
GROUP BY session_id, user_id
HAVING TIMESTAMPDIFF(MINUTE, MIN(event_timestamp), MAX(event_timestamp)) > 30 AND SUM(event_type = 'scroll') >= 5 AND SUM(event_type = 'click') / COUNT(*) < 0.20 AND SUM(event_type = 'purchase') = 0
ORDER BY scroll_count DESC, session_id;
