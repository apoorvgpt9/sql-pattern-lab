-- breaks: edge_typical, edge_thirds, edge_none_immediate, edge_all_immediate
-- MISTAKE: ignores "first order" and takes the share of immediate orders over ALL orders.
-- Customers with many orders are over-weighted, and later orders leak in.
SELECT ROUND(100 * AVG(customer_pref_delivery_date = order_date), 2) AS immediate_percentage
FROM Delivery;
