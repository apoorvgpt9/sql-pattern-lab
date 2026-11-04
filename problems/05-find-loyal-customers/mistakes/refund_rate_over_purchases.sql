-- breaks: edge_refund_rate
-- MISTAKE: dividing refunds by purchases instead of by all transactions. The spec's denominator is purchases + refunds.
-- (1 refund / 5 purchases = 0.20 is out, but 1 / 6 transactions = 0.167 is in.)
SELECT customer_id
FROM customer_transactions
GROUP BY customer_id
HAVING SUM(transaction_type = 'purchase') >= 3
   AND DATEDIFF(MAX(transaction_date), MIN(transaction_date)) >= 30
   AND SUM(transaction_type = 'refund') / SUM(transaction_type = 'purchase') < 0.2
ORDER BY customer_id;
