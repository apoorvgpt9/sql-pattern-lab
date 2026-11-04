-- Exchange Seats (LeetCode 626): tables for MySQL 8.0. Names mirror the original.
-- Spec guarantee: ids start at 1 and are contiguous. Nothing in the schema enforces it.

CREATE TABLE Seat (
  id      INT PRIMARY KEY,   -- grain: one row per seat
  student VARCHAR(100)
);
