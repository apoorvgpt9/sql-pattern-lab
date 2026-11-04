-- One customer who qualifies and one who fails each criterion in turn.
INSERT INTO customer_transactions (transaction_id, customer_id, transaction_date, amount, transaction_type) VALUES
  (1,  10, '2024-01-01', 10.00, 'purchase'),
  (2,  10, '2024-01-15', 10.00, 'purchase'),
  (3,  10, '2024-02-05', 10.00, 'purchase'),
  (4,  20, '2024-03-01', 10.00, 'purchase'),
  (5,  20, '2024-03-05', 10.00, 'purchase'),
  (6,  20, '2024-03-10', 10.00, 'purchase'),
  (7,  30, '2024-01-01', 10.00, 'purchase'),
  (8,  30, '2024-03-01', 10.00, 'purchase'),
  (9,  40, '2024-01-01', 10.00, 'purchase'),
  (10, 40, '2024-01-20', 10.00, 'purchase'),
  (11, 40, '2024-02-20', 10.00, 'purchase'),
  (12, 40, '2024-02-21',  5.00, 'refund'),
  (13, 40, '2024-02-22',  5.00, 'refund');

-- expect: 10 | 3 purchases; span 2024-01-01..2024-02-05 = 35 days >= 30; no refunds (rate 0 < 0.20)
--   customer 20: 3 purchases but all within 9 days -> span fails
--   customer 30: span is 60 days but only 2 purchases -> count fails
--   customer 40: 3 purchases, span 50 days, but 2 refunds out of 5 transactions = 0.40 -> rate fails
