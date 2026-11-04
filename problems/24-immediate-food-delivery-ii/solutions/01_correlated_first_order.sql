-- Approach 1 (brute force): keep an order only if its date is the earliest of its customer, found with
-- a correlated MIN subquery; then count the immediate ones among the survivors.
-- The first order of each customer is unique, so each customer contributes exactly one row.
SELECT ROUND(100 * SUM(d.customer_pref_delivery_date = d.order_date) / COUNT(*), 2) AS immediate_percentage
FROM Delivery d
WHERE d.order_date = (SELECT MIN(x.order_date)
                        FROM Delivery x
                       WHERE x.customer_id = d.customer_id);
