-- Approach 3 (optimal): collapse Confirmations to one row per user first (conditional aggregation),
-- then LEFT JOIN that narrow result onto Signups. The join is 1:1 from the Signups side.
WITH per_user AS (
  SELECT user_id,
         SUM(action = 'confirmed') AS n_confirmed,
         COUNT(*)                  AS n_requests
  FROM Confirmations
  GROUP BY user_id
)
SELECT s.user_id,
       ROUND(COALESCE(p.n_confirmed / p.n_requests, 0), 2) AS confirmation_rate
FROM Signups s
LEFT JOIN per_user p ON p.user_id = s.user_id;
