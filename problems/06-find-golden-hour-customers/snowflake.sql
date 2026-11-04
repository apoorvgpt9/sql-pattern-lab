-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9.
WITH per_customer AS (
  SELECT customer_id,
         COUNT(*)            AS total_orders,
         COUNT_IF(TO_TIME(order_timestamp) BETWEEN '11:00:00' AND '14:00:00'
               OR TO_TIME(order_timestamp) BETWEEN '18:00:00' AND '21:00:00') AS peak_orders,
         COUNT(order_rating) AS rated_orders,
         AVG(order_rating)   AS avg_rating
  FROM restaurant_orders
  GROUP BY customer_id
)
SELECT customer_id,
       total_orders,
       ROUND(100 * peak_orders / total_orders, 0) AS peak_hour_percentage,
       ROUND(avg_rating, 2)                       AS average_rating
FROM per_customer
WHERE total_orders >= 3
  AND 5 * peak_orders >= 3 * total_orders
  AND 2 * rated_orders >= total_orders
  AND avg_rating >= 4
ORDER BY average_rating DESC, customer_id DESC;
