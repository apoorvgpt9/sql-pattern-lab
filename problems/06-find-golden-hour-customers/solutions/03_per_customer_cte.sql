-- Approach 3 (optimal): one pass, one GROUP BY customer_id, every measure computed ONCE in a per-customer CTE; the
-- criteria are then plain predicates over that small result. The peak test is a 0/1 flag summed inside the aggregate.
-- Shares are compared as integer cross-products (5 * peak >= 3 * total  <=>  peak / total >= 0.6), so rounding can never
-- move a customer across a threshold. (Repeating the TIME() test in both SELECT and HAVING computes it twice per row.)
WITH per_customer AS (
  SELECT customer_id,
         COUNT(*)                                                   AS total_orders,
         SUM(TIME(order_timestamp) BETWEEN '11:00:00' AND '14:00:00'
          OR TIME(order_timestamp) BETWEEN '18:00:00' AND '21:00:00') AS peak_orders,
         COUNT(order_rating)                                        AS rated_orders,
         AVG(order_rating)                                          AS avg_rating
  FROM restaurant_orders
  GROUP BY customer_id
)
SELECT customer_id,
       total_orders,
       ROUND(100 * peak_orders / total_orders) AS peak_hour_percentage,
       ROUND(avg_rating, 2)                    AS average_rating
FROM per_customer
WHERE total_orders >= 3
  AND 5 * peak_orders >= 3 * total_orders
  AND 2 * rated_orders >= total_orders
  AND avg_rating >= 4
ORDER BY average_rating DESC, customer_id DESC;
