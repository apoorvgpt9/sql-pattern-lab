-- Approach 1 (brute force): a row qualifies if it is the first, middle or last row of some
-- triple of busy days with ids (x, x+1, x+2). Three copies of the table, one per position.
-- Natural first attempt: it spells out "three consecutive ids" literally.
-- DISTINCT is required: a row inside a run of 4+ belongs to several triples.
SELECT DISTINCT s1.id, s1.visit_date, s1.people
FROM Stadium s1
JOIN Stadium s2 ON s2.people >= 100
JOIN Stadium s3 ON s3.people >= 100
WHERE s1.people >= 100
  AND (   (s2.id = s1.id + 1 AND s3.id = s1.id + 2)   -- s1 starts the triple
       OR (s2.id = s1.id - 1 AND s3.id = s1.id + 1)   -- s1 is in the middle
       OR (s2.id = s1.id - 2 AND s3.id = s1.id - 1))  -- s1 ends the triple
ORDER BY s1.visit_date;
