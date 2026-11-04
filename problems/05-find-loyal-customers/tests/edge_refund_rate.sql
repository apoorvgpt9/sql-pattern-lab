-- Refund rate = refunds / all transactions (purchases + refunds), strictly below 0.20. Every customer has a
-- span >= 30 days and at least 3 purchases, so only the rate decides.
INSERT INTO customer_transactions (transaction_id, customer_id, transaction_date, amount, transaction_type) VALUES
  (1,  1, '2024-01-01', 10.00, 'purchase'),
  (2,  1, '2024-01-10', 10.00, 'purchase'),
  (3,  1, '2024-01-20', 10.00, 'purchase'),
  (4,  1, '2024-02-10', 10.00, 'purchase'),
  (5,  1, '2024-02-11',  5.00, 'refund'),
  (6,  2, '2024-01-01', 10.00, 'purchase'),
  (7,  2, '2024-01-10', 10.00, 'purchase'),
  (8,  2, '2024-01-20', 10.00, 'purchase'),
  (9,  2, '2024-02-10', 10.00, 'purchase'),
  (10, 2, '2024-02-11', 10.00, 'purchase'),
  (11, 2, '2024-02-12',  5.00, 'refund'),
  (12, 3, '2024-01-01', 10.00, 'purchase'),
  (13, 3, '2024-01-10', 10.00, 'purchase'),
  (14, 3, '2024-02-10', 10.00, 'purchase'),
  (15, 3, '2024-02-11',  5.00, 'refund');

-- expect: 2 | 5 purchases + 1 refund: 1 / 6 = 0.1667 < 0.20; span 42 days
--   customer 1: 4 purchases + 1 refund: 1 / 5 = 0.20 exactly: NOT strictly below -> out
--   customer 3: 3 purchases + 1 refund: 1 / 4 = 0.25 -> out
