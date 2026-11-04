-- breaks: edge_span_includes_refunds
-- MISTAKE: measuring the activity span over purchases only. The spec measures it over every transaction type.
SELECT customer_id
FROM customer_transactions
GROUP BY customer_id
HAVING SUM(transaction_type = 'purchase') >= 3
   AND DATEDIFF(MAX(CASE WHEN transaction_type = 'purchase' THEN transaction_date END),
                MIN(CASE WHEN transaction_type = 'purchase' THEN transaction_date END)) >= 30
   AND 5 * SUM(transaction_type = 'refund') < COUNT(*)
ORDER BY customer_id;
