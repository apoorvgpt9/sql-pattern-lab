-- Approach 2: LEFT JOIN every signup to its requests, then GROUP BY user.
-- AVG over a 0/1 expression is the confirmed share; a user with no rows gets NULL from AVG -> IFNULL to 0.
SELECT s.user_id,
       ROUND(IFNULL(AVG(c.action = 'confirmed'), 0), 2) AS confirmation_rate
FROM Signups s
LEFT JOIN Confirmations c ON c.user_id = s.user_id
GROUP BY s.user_id;
