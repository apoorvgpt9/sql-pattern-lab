-- Typical tree, four levels deep, rows inserted in shuffled order (children before parents).
-- Node 30 has two children; node 60 has one child, which is still enough to be Inner.
--
--            10
--          /    \
--        20      30
--       /  \    /  \
--     40   50  60   15
--              |
--              70
INSERT INTO Tree (id, p_id) VALUES
  (70, 60),
  (40, 20),
  (10, NULL),
  (15, 30),
  (60, 30),
  (20, 10),
  (50, 20),
  (30, 10);

-- expect: 10,Root | p_id NULL; it also has children (20, 30), but Root is checked first
-- expect: 20,Inner | has a parent (10) and two children (40, 50)
-- expect: 30,Inner | has a parent (10) and two children (60, 15)
-- expect: 40,Leaf | has a parent (20); no row has p_id = 40
-- expect: 50,Leaf | has a parent (20); no row has p_id = 50
-- expect: 60,Inner | has a parent (30) and exactly one child (70)
-- expect: 15,Leaf | has a parent (30); no row has p_id = 15 (id smaller than its parent's: ids carry no depth)
-- expect: 70,Leaf | deepest node; no row has p_id = 70
