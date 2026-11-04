-- Typical mix: every category populated, two accounts with the same income (both count).
INSERT INTO Accounts (account_id, income) VALUES
  (1,  9000),    -- Low
  (2,  8000),    -- Low
  (3, 12000),    -- Low
  (4, 35000),    -- Average
  (5, 35000),    -- Average; same income as account 4: a separate account, so it counts again
  (6, 62000),    -- High
  (7, 90000),    -- High
  (8, 150000);   -- High

-- expect: Low Salary,3 | accounts 1, 2, 3 are below 20000
-- expect: Average Salary,2 | accounts 4 and 5 (equal incomes are still two accounts)
-- expect: High Salary,3 | accounts 6, 7, 8 are above 50000
