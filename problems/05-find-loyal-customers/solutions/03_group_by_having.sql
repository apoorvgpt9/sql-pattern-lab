-- Approach 3 (optimal): one pass, one GROUP BY customer_id; each criterion is one HAVING predicate over a
-- (conditional) aggregate. The refund rate is compared as 5 * refunds < total, in integers: refunds / total < 0.2
-- without any division, so no rounding can move a value across the 0.20 boundary.
SELECT customer_id
FROM customer_transactions
GROUP BY customer_id
HAVING SUM(transaction_type = 'purchase') >= 3
   AND DATEDIFF(MAX(transaction_date), MIN(transaction_date)) >= 30
   AND 5 * SUM(transaction_type = 'refund') < COUNT(*)
ORDER BY customer_id;
