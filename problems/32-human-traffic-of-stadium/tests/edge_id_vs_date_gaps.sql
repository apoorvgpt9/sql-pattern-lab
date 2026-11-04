-- Consecutiveness is on id, not on visit_date.
-- ids 1-3: consecutive ids, dates skip (05-01, 05-03, 05-10) -> a run of 3.
-- ids 5, 6, 8: consecutive dates (05-11..05-13) but ids 4 and 7 do not exist -> no run of 3.
INSERT INTO Stadium (id, visit_date, people) VALUES
  (1, '2024-05-01', 150),
  (2, '2024-05-03', 150),
  (3, '2024-05-10', 150),
  (5, '2024-05-11', 150),   -- id 4 missing: gap in id
  (6, '2024-05-12', 150),
  (8, '2024-05-13', 150);   -- id 7 missing: 5-6 is a run of 2, 8 a run of 1

-- expect: 1,2024-05-01,150 | ids 1, 2, 3 are consecutive; the date gaps do not matter
-- expect: 2,2024-05-03,150 | same run
-- expect: 3,2024-05-10,150 | same run; the next id (5) is not 4, so the run ends at length 3
