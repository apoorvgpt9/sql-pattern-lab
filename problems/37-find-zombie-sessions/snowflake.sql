-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- COUNT_IF replaces SUM(boolean). Duration uses whole elapsed minutes, FLOOR(seconds / 60), to match
-- MySQL's TIMESTAMPDIFF: Snowflake's DATEDIFF(minute, ...) counts minute boundaries crossed instead.
SELECT session_id, user_id,
       FLOOR(DATEDIFF(second, MIN(event_timestamp), MAX(event_timestamp)) / 60) AS session_duration_minutes,
       COUNT_IF(event_type = 'scroll') AS scroll_count
FROM app_events
GROUP BY session_id, user_id
HAVING FLOOR(DATEDIFF(second, MIN(event_timestamp), MAX(event_timestamp)) / 60) > 30
   AND COUNT_IF(event_type = 'scroll') >= 5
   AND COUNT_IF(event_type = 'click') / COUNT_IF(event_type = 'scroll') < 0.20
   AND COUNT_IF(event_type = 'purchase') = 0
ORDER BY scroll_count DESC, session_id;
