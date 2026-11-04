-- Approach 1 (brute force): for every customer compute each measure with its own correlated subquery,
-- then filter the resulting derived table.
SELECT customer_id, total_orders,
       ROUND(100 * peak_orders / total_orders) AS peak_hour_percentage,
       ROUND(avg_rating, 2)                    AS average_rating
FROM (
  SELECT c.customer_id,
         (SELECT COUNT(*) FROM restaurant_orders o
           WHERE o.customer_id = c.customer_id) AS total_orders,
         (SELECT COUNT(*) FROM restaurant_orders o
           WHERE o.customer_id = c.customer_id
             AND (TIME(o.order_timestamp) BETWEEN '11:00:00' AND '14:00:00'
               OR TIME(o.order_timestamp) BETWEEN '18:00:00' AND '21:00:00')) AS peak_orders,
         (SELECT COUNT(o.order_rating) FROM restaurant_orders o
           WHERE o.customer_id = c.customer_id) AS rated_orders,
         (SELECT AVG(o.order_rating) FROM restaurant_orders o
           WHERE o.customer_id = c.customer_id) AS avg_rating
  FROM (SELECT DISTINCT customer_id FROM restaurant_orders) c
) x
WHERE total_orders >= 3
  AND 5 * peak_orders >= 3 * total_orders
  AND 2 * rated_orders >= total_orders
  AND avg_rating >= 4
ORDER BY average_rating DESC, customer_id DESC;
