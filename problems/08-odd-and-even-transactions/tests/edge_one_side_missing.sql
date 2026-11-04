-- Days where only one parity exists: the missing side must be 0, not NULL and not a missing row.
INSERT INTO transactions (transaction_id, amount, transaction_date) VALUES
  (1, 9, '2024-05-01'),   -- only odd on this day
  (2, 3, '2024-05-01'),
  (3, 8, '2024-05-02'),   -- only even on this day
  (4, 2, '2024-05-02'),
  (5, 4, '2024-05-03'),   -- a single even transaction
  (6, 5, '2024-05-04');   -- a single odd transaction

-- expect: 2024-05-01,12,0 | odd: 9+3; no even transaction, so even_sum is 0 (not NULL)
-- expect: 2024-05-02,0,10 | no odd transaction, so odd_sum is 0; even: 8+2
-- expect: 2024-05-03,0,4 | single even transaction
-- expect: 2024-05-04,5,0 | single odd transaction
