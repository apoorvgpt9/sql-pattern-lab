-- One seat: the smallest odd count. It is both the first and the last seat.
INSERT INTO Seat (id, student) VALUES (1, 'Solo');

-- expect: 1,Solo | odd count with no partner at all: the seat keeps its student
