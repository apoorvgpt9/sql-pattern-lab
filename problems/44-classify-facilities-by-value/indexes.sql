-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (facid, memid, slots) is covering for every read of bookings in all three solutions:
--   03: GROUP BY facid can stream in index order (no temporary table), reading only the index;
--   01/02: the join + GROUP BY can read the narrow index instead of the full rows.
CREATE INDEX idx_bookings_fac_mem_slots ON bookings (facid, memid, slots);
