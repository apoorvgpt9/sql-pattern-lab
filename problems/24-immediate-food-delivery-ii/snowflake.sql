-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- QUALIFY keeps each customer's first order. It sits in a CTE because an aggregate in the same SELECT would
-- be evaluated before the window function.
WITH first_orders AS (
  SELECT order_date, customer_pref_delivery_date
  FROM Delivery
  QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) = 1
)
SELECT ROUND(100 * AVG(IFF(customer_pref_delivery_date = order_date, 1, 0)), 2) AS immediate_percentage
FROM first_orders;
