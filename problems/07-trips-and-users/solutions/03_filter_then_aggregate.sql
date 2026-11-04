-- Approach 3 (optimal): step 1 narrows Trips to the eligible ones, using the date range on the raw column and set
-- membership in the unbanned users (no join, so no extra columns or rows can arrive from Users). Step 2 is one
-- narrow aggregation over those trips.
WITH ok_users AS (
  SELECT users_id FROM Users WHERE banned = 'No'
), eligible AS (
  SELECT request_at, status
  FROM Trips
  WHERE request_at BETWEEN '2013-10-01' AND '2013-10-03'
    AND client_id IN (SELECT users_id FROM ok_users)
    AND driver_id IN (SELECT users_id FROM ok_users)
)
SELECT request_at AS Day,
       ROUND(SUM(status <> 'completed') / COUNT(*), 2) AS `Cancellation Rate`
FROM eligible
GROUP BY request_at;
