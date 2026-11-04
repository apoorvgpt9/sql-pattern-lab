-- breaks: edge_peak_boundaries
-- MISTAKE: peak test written with HOUR(): HOUR BETWEEN 11 AND 14 also accepts 14:00:01-14:59:59 (and 18-21 accepts 21:00:01-21:59:59), so orders one second past a window count as peak,.
SELECT customer_id, COUNT(*) AS total_orders,
       ROUND(100 * SUM((HOUR(order_timestamp) BETWEEN 11 AND 14 OR HOUR(order_timestamp) BETWEEN 18 AND 21)) / COUNT(*)) AS peak_hour_percentage,
       ROUND(AVG(order_rating), 2) AS average_rating
FROM restaurant_orders
GROUP BY customer_id
HAVING COUNT(*) >= 3
   AND 5 * SUM((HOUR(order_timestamp) BETWEEN 11 AND 14 OR HOUR(order_timestamp) BETWEEN 18 AND 21)) >= 3 * COUNT(*)
   AND 2 * COUNT(order_rating) >= COUNT(*)
   AND AVG(order_rating) >= 4
ORDER BY average_rating DESC, customer_id DESC;
