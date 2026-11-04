-- breaks: edge_typical, edge_rounding, edge_thirds, edge_all_immediate
-- MISTAKE: forgets the * 100: the result is a fraction (0.75) while the spec's scale is a percentage (75.00).
SELECT ROUND(AVG(d.customer_pref_delivery_date = d.order_date), 2) AS immediate_percentage
FROM Delivery d
JOIN (SELECT customer_id, MIN(order_date) AS first_date FROM Delivery GROUP BY customer_id) f
  ON f.customer_id = d.customer_id AND f.first_date = d.order_date;
