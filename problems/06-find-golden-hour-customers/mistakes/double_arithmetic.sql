-- breaks: edge_rounding
-- MISTAKE: forcing floating point "to be safe". A DOUBLE 62.5 and 4.125 are exactly representable, and ROUND on a DOUBLE rounds
-- an exact half to even (62 and 4.12), where DECIMAL rounds it away from zero (63 and 4.13).
SELECT customer_id, COUNT(*) AS total_orders,
       ROUND(100.0e0 * SUM(TIME(order_timestamp) BETWEEN '11:00:00' AND '14:00:00'
                        OR TIME(order_timestamp) BETWEEN '18:00:00' AND '21:00:00') / COUNT(*)) AS peak_hour_percentage,
       ROUND(CAST(AVG(order_rating) AS DOUBLE), 2) AS average_rating
FROM restaurant_orders
GROUP BY customer_id
HAVING COUNT(*) >= 3
   AND 5 * SUM(TIME(order_timestamp) BETWEEN '11:00:00' AND '14:00:00'
            OR TIME(order_timestamp) BETWEEN '18:00:00' AND '21:00:00') >= 3 * COUNT(*)
   AND 2 * COUNT(order_rating) >= COUNT(*)
   AND AVG(order_rating) >= 4
ORDER BY average_rating DESC, customer_id DESC;
