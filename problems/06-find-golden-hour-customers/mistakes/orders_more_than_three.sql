-- breaks: edge_threshold_boundaries
-- MISTAKE: 'at least 3 orders' written as > 3: exactly 3 orders must qualify.
SELECT customer_id, COUNT(*) AS total_orders,
       ROUND(100 * SUM((TIME(order_timestamp) BETWEEN '11:00:00' AND '14:00:00' OR TIME(order_timestamp) BETWEEN '18:00:00' AND '21:00:00')) / COUNT(*)) AS peak_hour_percentage,
       ROUND(AVG(order_rating), 2) AS average_rating
FROM restaurant_orders
GROUP BY customer_id
HAVING COUNT(*) > 3
   AND 5 * SUM((TIME(order_timestamp) BETWEEN '11:00:00' AND '14:00:00' OR TIME(order_timestamp) BETWEEN '18:00:00' AND '21:00:00')) >= 3 * COUNT(*)
   AND 2 * COUNT(order_rating) >= COUNT(*)
   AND AVG(order_rating) >= 4
ORDER BY average_rating DESC, customer_id DESC;
