-- breaks: edge_none_immediate
-- MISTAKE: SUM(CASE WHEN immediate THEN 1 END) has no ELSE. When no first order is immediate, every CASE is
-- NULL, the SUM is NULL, and the answer is NULL instead of 0.00.
SELECT ROUND(100 * SUM(CASE WHEN d.customer_pref_delivery_date = d.order_date THEN 1 END) / COUNT(*), 2) AS immediate_percentage
FROM Delivery d
JOIN (SELECT customer_id, MIN(order_date) AS first_date FROM Delivery GROUP BY customer_id) f
  ON f.customer_id = d.customer_id AND f.first_date = d.order_date;
