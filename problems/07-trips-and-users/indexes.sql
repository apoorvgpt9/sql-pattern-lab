-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (request_at, client_id, driver_id, status) is covering for the Trips side of all three solutions and starts with the
-- range column, so the 3-day filter becomes an index range scan instead of a full table scan:
--   01: each per-day subquery is an index range read of one day;
--   02, 03: only the 3-day slice of the index is read; the unbanned-user checks stay primary-key lookups on Users.
-- Users needs no extra index: users_id is the primary key.
CREATE INDEX idx_trips_day_users_status ON Trips (request_at, client_id, driver_id, status);
