-- breaks: edge_ordering
-- MISTAKE: no ORDER BY. A GROUP BY result has no promised order; here it comes out in the order groups were first
-- seen (the insertion order 30, 10, 20), not ascending. The spec wants customer_id ascending.
SELECT customer_id
FROM customer_transactions
GROUP BY customer_id
HAVING SUM(transaction_type = 'purchase') >= 3
   AND DATEDIFF(MAX(transaction_date), MIN(transaction_date)) >= 30
   AND 5 * SUM(transaction_type = 'refund') < COUNT(*);
