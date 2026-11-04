-- breaks: edge_odd_count, edge_single_seat
-- MISTAKE: joining each seat to its partner with an INNER JOIN. The last odd seat has no partner row,
-- so it disappears from the output instead of keeping its student.
SELECT s.id, t.student
FROM Seat s
JOIN Seat t ON t.id = CASE WHEN s.id % 2 = 1 THEN s.id + 1 ELSE s.id - 1 END
ORDER BY s.id;
