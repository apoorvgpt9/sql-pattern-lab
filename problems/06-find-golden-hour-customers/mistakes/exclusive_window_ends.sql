-- breaks: edge_peak_boundaries
-- MISTAKE: windows written with strict < and >. The spec's endpoints (11:00:00, 14:00:00, 18:00:00, 21:00:00) are inside the window, so customer 1 of the dataset loses every boundary order.
SELECT customer_id, COUNT(*) AS total_orders,
       ROUND(100 * SUM((TIME(order_timestamp) > '11:00:00' AND TIME(order_timestamp) < '14:00:00' OR TIME(order_timestamp) > '18:00:00' AND TIME(order_timestamp) < '21:00:00')) / COUNT(*)) AS peak_hour_percentage,
       ROUND(AVG(order_rating), 2) AS average_rating
FROM restaurant_orders
GROUP BY customer_id
HAVING COUNT(*) >= 3
   AND 5 * SUM((TIME(order_timestamp) > '11:00:00' AND TIME(order_timestamp) < '14:00:00' OR TIME(order_timestamp) > '18:00:00' AND TIME(order_timestamp) < '21:00:00')) >= 3 * COUNT(*)
   AND 2 * COUNT(order_rating) >= COUNT(*)
   AND AVG(order_rating) >= 4
ORDER BY average_rating DESC, customer_id DESC;
