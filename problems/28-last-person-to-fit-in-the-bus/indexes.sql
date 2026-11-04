-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (turn, weight, person_name) is covering for all three solutions:
--   01: the self-join range turn <= x reads the index instead of the table;
--   02: the window scans the queue already in turn order, from the index;
--   03: each recursive step is one equality lookup on turn (turn = previous turn + 1) - without an index every
--       step scans the whole table, which turns "work proportional to the people who board" into "boarded people x queue length".
CREATE INDEX idx_queue_turn_cover ON Queue (turn, weight, person_name);
