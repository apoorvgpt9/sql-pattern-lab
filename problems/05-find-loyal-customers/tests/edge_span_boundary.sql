-- The 30-day span is inclusive (exactly 30 days qualifies) and DATEDIFF counts real calendar days, so a leap
-- February matters. All customers have exactly 3 purchases and no refunds.
INSERT INTO customer_transactions (transaction_id, customer_id, transaction_date, amount, transaction_type) VALUES
  (1,  1, '2024-01-01', 10.00, 'purchase'),
  (2,  1, '2024-01-10', 10.00, 'purchase'),
  (3,  1, '2024-01-31', 10.00, 'purchase'),
  (4,  2, '2024-01-01', 10.00, 'purchase'),
  (5,  2, '2024-01-10', 10.00, 'purchase'),
  (6,  2, '2024-01-30', 10.00, 'purchase'),
  (7,  3, '2024-05-05', 10.00, 'purchase'),
  (8,  3, '2024-05-05', 10.00, 'purchase'),
  (9,  3, '2024-05-05', 10.00, 'purchase'),
  (10, 4, '2024-02-01', 10.00, 'purchase'),
  (11, 4, '2024-02-15', 10.00, 'purchase'),
  (12, 4, '2024-03-02', 10.00, 'purchase');

-- expect: 1 | span 2024-01-01..2024-01-31 is exactly 30 days: qualifies (>= 30)
--   customer 2: span 29 days -> out
--   customer 3: three purchases on the same day: span 0 -> out
-- expect: 4 | 2024-02-01..2024-03-02 is 30 days only because 2024 is a leap year (Feb has 29 days) -> qualifies
