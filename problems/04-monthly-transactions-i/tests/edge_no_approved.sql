-- Groups with no approved row at all, one with two identical transactions (they differ only by id).
INSERT INTO Transactions (id, country, state, amount, trans_date) VALUES
  (1, 'FR', 'declined', 40, '2020-03-05'),
  (2, 'FR', 'declined', 40, '2020-03-05'),
  (3, 'FR', 'approved', 25, '2020-04-01'),
  (4, 'IT', 'declined', 15, '2020-03-05');

-- expect: 2020-03,FR,2,0,80,0 | two identical declined rows both count (80); no approved row: 0 and 0, not NULL
-- expect: 2020-04,FR,1,1,25,25 | one approved row
-- expect: 2020-03,IT,1,0,15,0 | declined only
