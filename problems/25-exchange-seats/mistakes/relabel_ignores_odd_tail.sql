-- breaks: edge_odd_count, edge_single_seat
-- MISTAKE: the relabel idea (odd -> id + 1, even -> id - 1) without the special case for the last seat.
-- With an odd count the last student is sent to id n + 1, a seat that does not exist, and seat n disappears.
SELECT CASE WHEN id % 2 = 1 THEN id + 1 ELSE id - 1 END AS id, student
FROM Seat
ORDER BY 1;
