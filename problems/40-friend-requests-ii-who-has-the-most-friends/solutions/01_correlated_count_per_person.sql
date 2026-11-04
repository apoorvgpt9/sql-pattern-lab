-- Approach 1 (brute force): list every person, then count their friendships one person at a time.
-- Natural first attempt: "for each person, how many rows mention them in either column?"
-- The OR covers both roles; a row cannot mention the same person twice (no self-friendship).
WITH people AS (
  SELECT requester_id AS id FROM RequestAccepted
  UNION                                   -- dedup is right HERE: this is a list of people, not of friendships
  SELECT accepter_id FROM RequestAccepted
)
SELECT
  p.id,
  (SELECT COUNT(*)
     FROM RequestAccepted r
    WHERE r.requester_id = p.id
       OR r.accepter_id  = p.id) AS num
FROM people p
ORDER BY num DESC
LIMIT 1;
