-- breaks: edge_thirds, edge_none_immediate, edge_all_immediate
-- MISTAKE: MAX(order_date) instead of MIN: measures each customer's LATEST order.
SELECT ROUND(100 * AVG(d.customer_pref_delivery_date = d.order_date), 2) AS immediate_percentage
FROM Delivery d
JOIN (SELECT customer_id, MAX(order_date) AS last_date FROM Delivery GROUP BY customer_id) f
  ON f.customer_id = d.customer_id AND f.last_date = d.order_date;
