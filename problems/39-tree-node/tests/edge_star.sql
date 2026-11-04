-- A star: one root with four children, all leaves. The root's id (100) appears four times as a p_id,
-- which is what duplicates rows in an un-deduplicated join to the children.
INSERT INTO Tree (id, p_id) VALUES
  (100, NULL),
  (5,   100),
  (3,   100),
  (9,   100),
  (1,   100);

-- expect: 100,Root | p_id NULL; four children, but one output row
-- expect: 5,Leaf | parent 100, no children
-- expect: 3,Leaf | parent 100, no children
-- expect: 9,Leaf | parent 100, no children
-- expect: 1,Leaf | parent 100, no children
