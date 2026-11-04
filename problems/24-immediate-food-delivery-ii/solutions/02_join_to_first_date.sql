-- Approach 2: compute every customer's first order date once with GROUP BY, then join back on
-- (customer_id, order_date) to get the first order itself; AVG of the immediate flag is the share.
SELECT ROUND(100 * AVG(d.customer_pref_delivery_date = d.order_date), 2) AS immediate_percentage
FROM Delivery d
JOIN (SELECT customer_id, MIN(order_date) AS first_date
        FROM Delivery
       GROUP BY customer_id) f
  ON  f.customer_id = d.customer_id
  AND f.first_date  = d.order_date;
