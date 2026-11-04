-- Fewer than three rows in total: even two identical rows cannot make a run of three.
INSERT INTO Logs (id, num) VALUES (1, 'Z'), (2, 'Z');

-- expect-empty: only two rows exist
