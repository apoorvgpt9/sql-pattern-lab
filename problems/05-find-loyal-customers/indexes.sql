-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (customer_id, transaction_type, transaction_date) is covering for all three solutions (no other column is read):
--   01: every per-customer subquery becomes an index range read of that customer's entries
--       (MIN/MAX of the date can use the ends of the range only when the type is fixed; COUNTs just count entries);
--   02, 03: the GROUP BY customer_id arrives in index order, so the aggregation streams without a temporary table.
CREATE INDEX idx_tx_customer_type_date ON customer_transactions (customer_id, transaction_type, transaction_date);
