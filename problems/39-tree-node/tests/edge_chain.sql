-- A chain (every node has exactly one child), ids deliberately not in depth order: 4 -> 2 -> 5 -> 1 -> 3.
-- Every node with one child is Inner; a "count children >= 2" reading of Inner would be wrong.
INSERT INTO Tree (id, p_id) VALUES
  (1, 5),
  (2, 4),
  (3, 1),
  (4, NULL),
  (5, 2);

-- expect: 4,Root | p_id NULL (it has one child, 2)
-- expect: 2,Inner | parent 4, one child (5)
-- expect: 5,Inner | parent 2, one child (1)
-- expect: 1,Inner | parent 5, one child (3)
-- expect: 3,Leaf | parent 1; no row has p_id = 3
