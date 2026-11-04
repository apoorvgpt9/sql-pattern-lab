-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (user_id, action) is covering for all three solutions (no other Confirmations column is read):
--   01: each correlated COUNT(*) becomes an index range read of one user's entries;
--   02: the join can probe the index instead of building a hash table;
--   03: the GROUP BY can stream in user_id order instead of using a temporary table.
-- The table's PK is (user_id, time_stamp), which already supports the user_id lookup, but it is not covering
-- for `action`, so every probe would also read the clustered row.
CREATE INDEX idx_confirmations_user_action ON Confirmations (user_id, action);
