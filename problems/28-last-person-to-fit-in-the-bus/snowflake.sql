-- UNVERIFIED: Snowflake version of the optimal approach. CI cannot run Snowflake.
-- This is NOT the MySQL recursive CTE (approach 03): Snowflake has no index to make each recursive step a cheap
-- lookup, so the recommended form there is a window over a bounded prefix of the queue (README section 9).
-- Bound: weights are positive integers, so at most 1000 people can board; turns run 1..n, so turn <= 1000 covers them all.
SELECT person_name
FROM Queue
WHERE turn <= 1000
QUALIFY SUM(weight) OVER (ORDER BY turn ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) <= 1000
ORDER BY turn DESC
LIMIT 1;
