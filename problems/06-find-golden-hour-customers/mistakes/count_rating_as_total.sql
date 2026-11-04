-- breaks: edge_null_ratings
-- MISTAKE: total_orders (and the shares' denominator) taken from COUNT(order_rating). That counts rated orders only, so
-- unrated orders vanish from the order total: customer 1 of the dataset shows 2 orders instead of 4 and fails the minimum.
SELECT customer_id, COUNT(order_rating) AS total_orders,
       ROUND(100 * SUM(TIME(order_timestamp) BETWEEN '11:00:00' AND '14:00:00'
                    OR TIME(order_timestamp) BETWEEN '18:00:00' AND '21:00:00') / COUNT(order_rating)) AS peak_hour_percentage,
       ROUND(AVG(order_rating), 2) AS average_rating
FROM restaurant_orders
GROUP BY customer_id
HAVING COUNT(order_rating) >= 3
   AND 5 * SUM(TIME(order_timestamp) BETWEEN '11:00:00' AND '14:00:00'
            OR TIME(order_timestamp) BETWEEN '18:00:00' AND '21:00:00') >= 3 * COUNT(order_rating)
   AND AVG(order_rating) >= 4
ORDER BY average_rating DESC, customer_id DESC;
