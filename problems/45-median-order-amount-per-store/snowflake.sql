-- UNVERIFIED: Snowflake version. CI cannot run Snowflake.
-- Snowflake has an exact MEDIAN aggregate (the mean of the two middle values when n is even), so the
-- positional logic of approach 03 collapses to one GROUP BY. See README section 9.
SELECT store_id,
       ROUND(MEDIAN(amount), 2) AS median_amount
FROM StoreOrders
GROUP BY store_id
ORDER BY store_id;

-- Equivalent ANSI form: ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount), 2)
