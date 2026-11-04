-- Rows inserted in scrambled date order, spanning a year boundary and a month boundary.
-- The result must be sorted by the DATE value ascending (not by transaction_id, not by insertion).
INSERT INTO transactions (transaction_id, amount, transaction_date) VALUES
  (1, 3, '2024-01-02'),
  (2, 4, '2023-12-31'),
  (3, 5, '2024-01-01'),
  (4, 6, '2023-02-28'),
  (5, 7, '2024-03-01'),
  (6, 8, '2024-02-29');

-- expect: 2023-02-28,0,6 | earliest date: sorts first although id 4 is not the lowest id
-- expect: 2023-12-31,0,4 | second: 2023 sorts before 2024
-- expect: 2024-01-01,5,0 | third
-- expect: 2024-01-02,3,0 | fourth
-- expect: 2024-02-29,0,8 | fifth (leap day)
-- expect: 2024-03-01,7,0 | last
