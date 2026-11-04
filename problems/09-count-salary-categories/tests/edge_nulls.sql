-- NULL income (assumption in README): it satisfies none of the three conditions, so it is counted nowhere.
-- A CASE whose last branch is a bare ELSE 'High Salary' would swallow it.
INSERT INTO Accounts (account_id, income) VALUES
  (1, NULL),
  (2, NULL),
  (3, 10000),
  (4, 40000),
  (5, NULL);

-- expect: Low Salary,1 | account 3 only
-- expect: Average Salary,1 | account 4 only
-- expect: High Salary,0 | the three NULL-income accounts are NOT high earners
