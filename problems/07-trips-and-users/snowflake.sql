-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9.
WITH ok_users AS (
  SELECT users_id FROM Users WHERE banned = 'No'
), eligible AS (
  SELECT request_at, status
  FROM Trips
  WHERE request_at BETWEEN '2013-10-01' AND '2013-10-03'
    AND client_id IN (SELECT users_id FROM ok_users)
    AND driver_id IN (SELECT users_id FROM ok_users)
)
SELECT request_at AS "Day",
       ROUND(COUNT_IF(status <> 'completed') / COUNT(*), 2) AS "Cancellation Rate"
FROM eligible
GROUP BY request_at;
