-- The 30-day span is measured over ALL of a customer's transactions (any type), as the spec says. Customer 1's
-- purchases span only 4 days, but their refund 2 months later stretches the span.
INSERT INTO customer_transactions (transaction_id, customer_id, transaction_date, amount, transaction_type) VALUES
  (1,  1, '2024-01-01', 10.00, 'purchase'),
  (2,  1, '2024-01-02', 10.00, 'purchase'),
  (3,  1, '2024-01-03', 10.00, 'purchase'),
  (4,  1, '2024-01-04', 10.00, 'purchase'),
  (5,  1, '2024-01-05', 10.00, 'purchase'),
  (6,  1, '2024-03-01',  5.00, 'refund'),
  (7,  2, '2024-01-01', 10.00, 'purchase'),
  (8,  2, '2024-01-02', 10.00, 'purchase'),
  (9,  2, '2024-01-03', 10.00, 'purchase'),
  (10, 2, '2024-01-04', 10.00, 'purchase'),
  (11, 2, '2024-01-05', 10.00, 'purchase'),
  (12, 2, '2024-01-03',  5.00, 'refund');

-- expect: 1 | 5 purchases, 1 refund (1/6 = 0.1667 < 0.20); span over all types 2024-01-01..2024-03-01 = 60 days >= 30
--   customer 2: same shape but the refund falls inside the purchase window: span 4 days -> out
