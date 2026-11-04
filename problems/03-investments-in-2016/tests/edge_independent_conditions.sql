-- The two conditions are evaluated against the WHOLE table independently. A policy's tiv_2015 partner
-- does not have to qualify itself.
INSERT INTO Insurance (pid, tiv_2015, tiv_2016, lat, lon) VALUES
  (1, 10.0, 1.0, 1.0, 1.0),
  (2, 10.0, 2.0, 9.0, 9.0),
  (3, 20.0, 4.0, 9.0, 9.0),
  (4, 30.0, 8.0, 4.0, 4.0);

-- expect: 1.00 | only pid 1 qualifies: tiv 10 is shared with pid 2 (who is out because of location), and (1,1) is unique
--   pid 2: tiv shared, but (9,9) is shared with pid 3 -> out. pid 3: tiv 20 is unique -> out. pid 4: tiv 30 is unique -> out.
--   Filtering by location first and then looking for tiv twins among the survivors loses pid 1 (its twin was filtered away).
