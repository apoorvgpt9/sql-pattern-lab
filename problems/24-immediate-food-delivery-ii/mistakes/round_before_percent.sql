-- breaks: edge_rounding, edge_thirds
-- MISTAKE: rounds the fraction to 2 decimals and then multiplies by 100: ROUND(3/7, 2) * 100 = 43.00 and
-- ROUND(1/3, 2) * 100 = 33.00. The percentage has to be rounded, not the fraction.
SELECT ROUND(AVG(d.customer_pref_delivery_date = d.order_date), 2) * 100 AS immediate_percentage
FROM Delivery d
JOIN (SELECT customer_id, MIN(order_date) AS first_date FROM Delivery GROUP BY customer_id) f
  ON f.customer_id = d.customer_id AND f.first_date = d.order_date;
