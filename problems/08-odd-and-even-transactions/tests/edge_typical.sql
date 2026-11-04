-- Typical mix: three days, each with odd and even amounts, one day where two transactions
-- carry the same amount (both must be summed), and ids whose parity disagrees with the amount's.
INSERT INTO transactions (transaction_id, amount, transaction_date) VALUES
  (1, 150, '2024-03-01'),  -- even
  (2,  35, '2024-03-01'),  -- odd; id 2 is even but the AMOUNT decides
  (3,  35, '2024-03-01'),  -- same amount as id 2: both count (SUM, not SUM DISTINCT)
  (4,  20, '2024-03-02'),  -- even
  (5,  21, '2024-03-02'),  -- odd
  (6,  10, '2024-03-03'),  -- even
  (7,  12, '2024-03-03'),  -- even
  (8,   7, '2024-03-03');  -- odd

-- expect: 2024-03-01,70,150 | odd: 35+35 = 70; even: 150
-- expect: 2024-03-02,21,20 | odd: 21; even: 20
-- expect: 2024-03-03,7,22 | odd: 7; even: 10+12 = 22
