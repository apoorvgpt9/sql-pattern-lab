-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- A secondary index on income already contains account_id (the PK), so it covers every query here
-- (nothing else is read): approach 1's three counts become three index range reads, and approaches
-- 2 and 3 scan the narrow index instead of the clustered table.
CREATE INDEX idx_accounts_income ON Accounts (income);
