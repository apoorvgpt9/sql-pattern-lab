-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- The primary key (user_id, action_date, action) already serves the clean-day test in all three
-- solutions: it is in (user_id, action_date) order, so the GROUP BY / NOT EXISTS reads it directly.
-- This index adds the (user_id, action) prefix that approach 1's "where does this streak end"
-- subquery probes: without it, each probe reads every row of the user; with it, only the rows of
-- that user's action. Approaches 2 and 3 sort a materialised CTE, so they gain little (EXPLAIN
-- still shows the sort) - the bench "with indexes" table shows whether that holds.
CREATE INDEX idx_activity_user_action_date ON activity (user_id, action, action_date);
