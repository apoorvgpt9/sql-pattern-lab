-- 'x' appears four times and its first and third occurrences are two positions apart, but it is never
-- three in a row: x x y x x z. Counting occurrences, or comparing only the first and third rows of a triple, is wrong.
INSERT INTO Logs (id, num) VALUES
  (1, 'x'), (2, 'x'), (3, 'y'), (4, 'x'), (5, 'x'), (6, 'z');

-- expect-empty: 'x' is interrupted by 'y' after two rows, so there is no run of three
