-- breaks: edge_span_boundary
-- MISTAKE: "active for at least 30 days" written as > 30. Exactly 30 days qualifies.
SELECT customer_id
FROM customer_transactions
GROUP BY customer_id
HAVING SUM(transaction_type = 'purchase') >= 3
   AND DATEDIFF(MAX(transaction_date), MIN(transaction_date)) > 30
   AND 5 * SUM(transaction_type = 'refund') < COUNT(*)
ORDER BY customer_id;
