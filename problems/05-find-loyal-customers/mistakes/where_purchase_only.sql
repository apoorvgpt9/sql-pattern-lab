-- breaks: edge_typical, edge_refund_rate, edge_span_includes_refunds
-- MISTAKE: "purchase" filtered in WHERE. The refund rows vanish, so the refund rate is always 0 (customers 40, 1, 3 of
-- the datasets leak in) and the span is measured over purchases only.
SELECT customer_id
FROM customer_transactions
WHERE transaction_type = 'purchase'
GROUP BY customer_id
HAVING COUNT(*) >= 3 AND DATEDIFF(MAX(transaction_date), MIN(transaction_date)) >= 30
ORDER BY customer_id;
