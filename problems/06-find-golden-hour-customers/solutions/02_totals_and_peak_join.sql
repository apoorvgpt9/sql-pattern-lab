-- Approach 2: one aggregate over all orders (count, rated count, average rating) and a second one over the
-- peak orders only, joined on customer. A customer with no peak order cannot reach 60%, so an inner join is safe.
WITH totals AS (
  SELECT customer_id, COUNT(*) AS total_orders, COUNT(order_rating) AS rated_orders, AVG(order_rating) AS avg_rating
  FROM restaurant_orders
  GROUP BY customer_id
), peak AS (
  SELECT customer_id, COUNT(*) AS peak_orders
  FROM restaurant_orders
  WHERE TIME(order_timestamp) BETWEEN '11:00:00' AND '14:00:00'
     OR TIME(order_timestamp) BETWEEN '18:00:00' AND '21:00:00'
  GROUP BY customer_id
)
SELECT t.customer_id, t.total_orders,
       ROUND(100 * p.peak_orders / t.total_orders) AS peak_hour_percentage,
       ROUND(t.avg_rating, 2)                      AS average_rating
FROM totals t
JOIN peak p ON p.customer_id = t.customer_id
WHERE t.total_orders >= 3
  AND 5 * p.peak_orders >= 3 * t.total_orders
  AND 2 * t.rated_orders >= t.total_orders
  AND t.avg_rating >= 4
ORDER BY average_rating DESC, t.customer_id DESC;
