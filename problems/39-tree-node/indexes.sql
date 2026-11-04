-- Index recommended in README "At scale" (b). The bench runs every solution without it, then with it.
-- (p_id) answers "does any row have p_id = this id?" as one index probe:
--   01: the IN / NOT IN semijoin and antijoin can probe instead of hashing a full copy of p_id;
--   02: each correlated EXISTS becomes an index lookup instead of a full scan per node;
--   03: SELECT DISTINCT p_id can read the index in order (a loose index scan) instead of a temp table.
CREATE INDEX idx_tree_p_id ON Tree (p_id);
