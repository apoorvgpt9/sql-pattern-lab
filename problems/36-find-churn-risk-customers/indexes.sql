-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (user_id, event_date, event_id) is the "latest event per user" order:
--   01: the correlated ORDER BY event_date DESC, event_id DESC LIMIT 1 and the MAX/MIN/EXISTS
--       probes become per-user index lookups instead of full table scans per row;
--   02: MySQL still sorts for the window (EXPLAIN keeps the Sort), so little changes;
--   03: the history GROUP BY becomes a streaming "Group aggregate" over the index instead of a
--       temporary table; the ROW_NUMBER pass still sorts.
CREATE INDEX idx_events_user_date_id ON subscription_events (user_id, event_date, event_id);
