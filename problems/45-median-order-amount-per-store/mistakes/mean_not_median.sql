-- breaks: edge_typical, edge_rounding
-- MISTAKE: AVG over all orders is the mean. It equals the median only for symmetric data, which is
-- why it survives datasets of one or two orders per store (edge_order, edge_duplicates' store 30).
SELECT store_id, ROUND(AVG(amount), 2) AS median_amount
FROM StoreOrders
GROUP BY store_id
ORDER BY store_id;
