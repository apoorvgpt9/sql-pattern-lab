-- UNVERIFIED: Snowflake version of the optimal approach (03). CI cannot run Snowflake.
-- Same shape as MySQL; differences are noted in README section 9.
SELECT customer_id
FROM customer_transactions
GROUP BY customer_id
HAVING COUNT_IF(transaction_type = 'purchase') >= 3
   AND DATEDIFF('day', MIN(transaction_date), MAX(transaction_date)) >= 30
   AND 5 * COUNT_IF(transaction_type = 'refund') < COUNT(*)
ORDER BY customer_id;
