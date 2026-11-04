-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9.
WITH buyer_2019 AS (
  SELECT buyer_id, COUNT(*) AS n_orders
  FROM Orders
  WHERE order_date >= '2019-01-01'::DATE
    AND order_date <  '2020-01-01'::DATE   -- raw-column range: the form micro-partition pruning can use
  GROUP BY buyer_id
)
SELECT
  u.user_id                  AS buyer_id,
  u.join_date,
  ZEROIFNULL(b.n_orders)     AS orders_in_2019
FROM Users u
LEFT JOIN buyer_2019 b
  ON b.buyer_id = u.user_id;
