-- Friend Requests II: Who Has the Most Friends (LeetCode 602): tables for MySQL 8.0. Names mirror the original.
-- One row per accepted friendship. The PK forbids the same (requester, accepter) pair twice; the data
-- also never stores one friendship in both directions.

CREATE TABLE RequestAccepted (
  requester_id INT NOT NULL,
  accepter_id  INT NOT NULL,
  accept_date  DATE,
  PRIMARY KEY (requester_id, accepter_id)   -- grain: one row per accepted friendship
);
