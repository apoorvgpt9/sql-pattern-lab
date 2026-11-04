-- NULL amounts (assumption in README): NULL % 2 is NULL, so a NULL amount is neither odd nor even
-- and adds to neither sum - but the day still exists in the table, so it still gets a row.
INSERT INTO transactions (transaction_id, amount, transaction_date) VALUES
  (1, NULL, '2024-07-01'),  -- the only transaction of the day, amount unknown
  (2, 6,    '2024-07-02'),
  (3, NULL, '2024-07-02'),  -- NULL next to a real amount: ignored
  (4, 7,    '2024-07-03'),
  (5, NULL, '2024-07-03');

-- expect: 2024-07-01,0,0 | only a NULL amount: contributes to neither side, day still present
-- expect: 2024-07-02,0,6 | even: 6; the NULL amount is ignored
-- expect: 2024-07-03,7,0 | odd: 7; the NULL amount is ignored
