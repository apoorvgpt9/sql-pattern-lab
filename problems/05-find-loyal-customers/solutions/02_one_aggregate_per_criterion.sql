-- Approach 2: one small GROUP BY per criterion (purchase count, date span, refund share), each in its own
-- CTE, joined on customer_id. Three passes over the table.
WITH purchases AS (
  SELECT customer_id, COUNT(*) AS n_purchases
  FROM customer_transactions WHERE transaction_type = 'purchase' GROUP BY customer_id
), span AS (
  SELECT customer_id, DATEDIFF(MAX(transaction_date), MIN(transaction_date)) AS span_days
  FROM customer_transactions GROUP BY customer_id
), refunds AS (
  SELECT customer_id, SUM(transaction_type = 'refund') / COUNT(*) AS refund_rate
  FROM customer_transactions GROUP BY customer_id
)
SELECT p.customer_id
FROM purchases p
JOIN span    s ON s.customer_id = p.customer_id
JOIN refunds r ON r.customer_id = p.customer_id
WHERE p.n_purchases >= 3 AND s.span_days >= 30 AND r.refund_rate < 0.2
ORDER BY p.customer_id;
