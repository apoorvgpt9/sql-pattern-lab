-- Approach 1 (brute force): list the distinct customers, then test each criterion for each customer with
-- its own correlated subquery (one more scan per criterion).
SELECT c.customer_id
FROM (SELECT DISTINCT customer_id FROM customer_transactions) c
WHERE (SELECT COUNT(*) FROM customer_transactions t
        WHERE t.customer_id = c.customer_id AND t.transaction_type = 'purchase') >= 3
  AND DATEDIFF((SELECT MAX(t.transaction_date) FROM customer_transactions t WHERE t.customer_id = c.customer_id),
               (SELECT MIN(t.transaction_date) FROM customer_transactions t WHERE t.customer_id = c.customer_id)) >= 30
  AND (SELECT COUNT(*) FROM customer_transactions t
        WHERE t.customer_id = c.customer_id AND t.transaction_type = 'refund')
    / (SELECT COUNT(*) FROM customer_transactions t WHERE t.customer_id = c.customer_id) < 0.2
ORDER BY c.customer_id;
