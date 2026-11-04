-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (starttime, facid, memid, slots) is covering for the revenue computation of all three solutions:
--   01: each of the 31 correlated lookups becomes an index range read of that window's 15 days of bookings
--       (it still visits every booking once per window it falls in, and joins it to facilities each time);
--   02/03: the range predicate (03) or the date function (02) is evaluated on the narrow index, not the table.
--   Only 03 can turn its range into a bounded index range scan; 02 applies DATE() to the column, which cannot use the index for a range.
CREATE INDEX idx_bookings_starttime ON bookings (starttime, facid, memid, slots);
