-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (transaction_date, amount) is covering: all three solutions read only these two columns, and
-- grouping by transaction_date can then stream in index order with no temporary table.
CREATE INDEX idx_tx_date_amount ON transactions (transaction_date, amount);
