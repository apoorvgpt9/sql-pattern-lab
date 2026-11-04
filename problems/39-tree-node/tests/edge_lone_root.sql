-- A tree with a single node. It has no parent and no children: still Root, never Leaf.
INSERT INTO Tree (id, p_id) VALUES
  (7, NULL);

-- expect: 7,Root | p_id NULL; having no children does not make it a Leaf (Root wins because it is checked first)
