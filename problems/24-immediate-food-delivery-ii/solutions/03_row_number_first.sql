-- Approach 3 (optimal): one ordered pass. ROW_NUMBER() per customer by order_date marks each customer's
-- first order; the filter rn = 1 leaves exactly one row per customer, and AVG of the immediate flag over
-- those rows is the share. No join back, no second read of Delivery.
WITH first_orders AS (
  SELECT
    order_date,
    customer_pref_delivery_date,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS rn
  FROM Delivery
)
SELECT ROUND(100 * AVG(customer_pref_delivery_date = order_date), 2) AS immediate_percentage
FROM first_orders
WHERE rn = 1;
