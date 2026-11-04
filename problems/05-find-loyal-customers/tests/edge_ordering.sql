-- Output must be sorted by customer_id ascending. Customers are inserted in descending-then-mixed order
-- (30, 10, 20) so insertion order differs from the required order. All three qualify.
INSERT INTO customer_transactions (transaction_id, customer_id, transaction_date, amount, transaction_type) VALUES
  (1, 30, '2024-01-01', 10.00, 'purchase'),
  (2, 30, '2024-01-20', 10.00, 'purchase'),
  (3, 30, '2024-02-10', 10.00, 'purchase'),
  (4, 10, '2024-01-01', 10.00, 'purchase'),
  (5, 10, '2024-01-20', 10.00, 'purchase'),
  (6, 10, '2024-02-10', 10.00, 'purchase'),
  (7, 20, '2024-01-01', 10.00, 'purchase'),
  (8, 20, '2024-01-20', 10.00, 'purchase'),
  (9, 20, '2024-02-10', 10.00, 'purchase');

-- expect: 10 | qualifies (3 purchases, span 40 days, no refunds); first in ascending customer_id order
-- expect: 20 | qualifies; second
-- expect: 30 | qualifies; third, although its rows were inserted first
