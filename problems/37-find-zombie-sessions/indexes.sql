-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (session_id, user_id, event_type, event_timestamp) is covering for all three solutions, and its
-- prefix matches the GROUP BY session_id, user_id:
--   01: each correlated subquery becomes an index range read of one session instead of a full scan;
--   02: the per-type CTEs and the NOT EXISTS read the index; their GROUP BYs stream;
--   03: EXPLAIN changes from "Aggregate using temporary table" to a streaming "Group aggregate".
-- Putting event_type second, (session_id, event_type, ...), serves 01/02's per-type lookups slightly
-- better but makes 03 fall back to a temporary table, because user_id leaves the index prefix.
CREATE INDEX idx_events_session_user_type_ts ON app_events (session_id, user_id, event_type, event_timestamp);
