-- Both top-performer thresholds, at the boundary.
-- User 1: 5 courses, ratings 5+4+4+4+3 = 20 -> average exactly 4.0 -> qualifies (">= 4").
-- User 2: 5 courses, ratings 4+4+4+4+3 = 19 -> average 3.8 -> does not.
-- User 3: 4 courses all rated 5 -> average 5, but only 4 courses -> does not.
-- Every course name is unique to one user, so the output shows exactly who qualified.
INSERT INTO course_completions (user_id, course_id, course_name, completion_date, course_rating) VALUES
  (1, 1, 'Art',    '2024-01-01', 5),
  (1, 2, 'Bio',    '2024-02-01', 4),
  (1, 3, 'Chem',   '2024-03-01', 4),
  (1, 4, 'Dance',  '2024-04-01', 4),
  (1, 5, 'Econ',   '2024-05-01', 3),
  (2, 6, 'Fr',     '2024-01-01', 4),
  (2, 7, 'Geo',    '2024-02-01', 4),
  (2, 8, 'Hist',   '2024-03-01', 4),
  (2, 9, 'Ital',   '2024-04-01', 4),
  (2, 10, 'Jazz',  '2024-05-01', 3),
  (3, 11, 'Kor',   '2024-01-01', 5),
  (3, 12, 'Lat',   '2024-02-01', 5),
  (3, 13, 'Math',  '2024-03-01', 5),
  (3, 14, 'Norse', '2024-04-01', 5);

-- expect: Art,Bio,1 | user 1 (average exactly 4.0, 5 courses) qualifies; first transition
-- expect: Bio,Chem,1 | user 1, second transition
-- expect: Chem,Dance,1 | user 1, third transition
-- expect: Dance,Econ,1 | user 1, fourth transition (the last course, Econ, has no successor)
-- (User 2: average 3.8 < 4. User 3: only 4 courses < 5. Neither contributes a pair.)
