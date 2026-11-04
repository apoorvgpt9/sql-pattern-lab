-- Every account is Average, so Low and High have no rows at all. They must still be reported, with 0.
INSERT INTO Accounts (account_id, income) VALUES
  (1, 25000),
  (2, 30000),
  (3, 45000);

-- expect: Low Salary,0 | nobody below 20000, but the category must appear
-- expect: Average Salary,3 | all three accounts
-- expect: High Salary,0 | nobody above 50000, but the category must appear
