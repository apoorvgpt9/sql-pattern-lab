-- Negative amounts: in MySQL, -3 % 2 = -1 (the sign follows the dividend), so "amount % 2 = 1"
-- does not recognise negative odd numbers. Zero is even.
INSERT INTO transactions (transaction_id, amount, transaction_date) VALUES
  (1, -3, '2024-06-01'),  -- negative odd: -3 % 2 = -1
  (2, -4, '2024-06-01'),  -- negative even
  (3,  5, '2024-06-01'),  -- positive odd
  (4,  0, '2024-06-02'),  -- zero is even (adds nothing to the sum, but its day must still appear)
  (5, -7, '2024-06-03'),  -- a day whose only transaction is a negative odd
  (6, -2, '2024-06-04');  -- a day whose only transaction is a negative even

-- expect: 2024-06-01,2,-4 | odd: -3+5 = 2; even: -4
-- expect: 2024-06-02,0,0 | only a zero amount: even, sum 0; the day is present so it has a row
-- expect: 2024-06-03,-7,0 | odd: -7; no even
-- expect: 2024-06-04,0,-2 | no odd; even: -2
