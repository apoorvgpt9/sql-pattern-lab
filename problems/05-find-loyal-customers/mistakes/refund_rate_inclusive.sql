-- breaks: edge_refund_rate
-- MISTAKE: "refund rate less than 20%" written with <=. Exactly 20% (1 refund in 5) must NOT qualify.
SELECT customer_id
FROM customer_transactions
GROUP BY customer_id
HAVING SUM(transaction_type = 'purchase') >= 3
   AND DATEDIFF(MAX(transaction_date), MIN(transaction_date)) >= 30
   AND 5 * SUM(transaction_type = 'refund') <= COUNT(*)
ORDER BY customer_id;
