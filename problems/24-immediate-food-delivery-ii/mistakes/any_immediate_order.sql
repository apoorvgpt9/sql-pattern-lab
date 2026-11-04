-- breaks: edge_typical, edge_none_immediate
-- MISTAKE: share of customers with ANY immediate order, instead of customers whose FIRST order is immediate.
SELECT ROUND(100 * COUNT(DISTINCT CASE WHEN customer_pref_delivery_date = order_date THEN customer_id END)
             / COUNT(DISTINCT customer_id), 2) AS immediate_percentage
FROM Delivery;
