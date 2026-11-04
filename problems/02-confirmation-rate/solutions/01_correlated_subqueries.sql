-- Approach 1 (brute force): for each signup, count that user's requests and confirmed requests with
-- correlated scalar subqueries, and guard the zero case by hand.
SELECT s.user_id,
       ROUND(
         CASE
           WHEN (SELECT COUNT(*) FROM Confirmations c WHERE c.user_id = s.user_id) = 0 THEN 0
           ELSE (SELECT COUNT(*) FROM Confirmations c WHERE c.user_id = s.user_id AND c.action = 'confirmed')
              / (SELECT COUNT(*) FROM Confirmations c WHERE c.user_id = s.user_id)
         END, 2) AS confirmation_rate
FROM Signups s;
