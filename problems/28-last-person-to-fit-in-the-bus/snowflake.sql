-- UNVERIFIED: Snowflake version of the optimal approach. CI cannot run Snowflake.
-- Same idea as approach 03 (window running sum), with the input bounded first. The MySQL recursive CTE (approach 02)
-- is not ported: Snowflake has no index to make each recursive step a cheap lookup (README section 9).
-- Bound: weights are positive integers, so at most 1000 people can board; turns run 1..n, so turn <= 1000 covers them all.
SELECT person_name
FROM Queue
WHERE turn <= 1000
QUALIFY SUM(weight) OVER (ORDER BY turn ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) <= 1000
ORDER BY turn DESC
LIMIT 1;
