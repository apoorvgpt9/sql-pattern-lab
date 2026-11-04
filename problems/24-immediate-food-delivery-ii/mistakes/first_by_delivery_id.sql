-- breaks: edge_typical
-- MISTAKE: treats the smallest delivery_id as the customer's first order. delivery_id is only a key; it need not
-- follow order_date. Customer 3's earlier order has the larger id.
SELECT ROUND(100 * AVG(d.customer_pref_delivery_date = d.order_date), 2) AS immediate_percentage
FROM Delivery d
WHERE d.delivery_id = (SELECT MIN(x.delivery_id) FROM Delivery x WHERE x.customer_id = d.customer_id);
