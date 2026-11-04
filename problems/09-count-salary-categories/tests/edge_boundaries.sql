-- The cut-offs themselves: Low is strictly below 20000; Average is 20000..50000 INCLUSIVE; High is strictly above 50000.
INSERT INTO Accounts (account_id, income) VALUES
  (1,     0),   -- zero is below 20000
  (2, 19999),   -- one below the Low/Average cut-off: Low
  (3, 20000),   -- exactly on the cut-off: Average (Low is strict)
  (4, 50000),   -- exactly on the upper cut-off: Average (High is strict)
  (5, 50001),   -- one above: High
  (6, 20000);   -- a second account on the lower boundary

-- expect: Low Salary,2 | incomes 0 and 19999
-- expect: Average Salary,3 | incomes 20000, 50000 and 20000 (both ends are inclusive)
-- expect: High Salary,1 | income 50001
