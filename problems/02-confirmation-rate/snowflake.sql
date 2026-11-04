-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9.
WITH per_user AS (
  SELECT user_id,
         COUNT_IF(action = 'confirmed') AS n_confirmed,
         COUNT(*)                       AS n_requests
  FROM Confirmations
  GROUP BY user_id
)
SELECT s.user_id,
       ROUND(ZEROIFNULL(p.n_confirmed / p.n_requests), 2) AS confirmation_rate
FROM Signups s
LEFT JOIN per_user p
  ON p.user_id = s.user_id;
