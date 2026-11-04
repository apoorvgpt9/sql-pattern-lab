-- Nobody is a top performer: user 1 has 5 courses but average 3.4, user 2 has 3 excellent courses.
INSERT INTO course_completions (user_id, course_id, course_name, completion_date, course_rating) VALUES
  (1, 1, 'Art',   '2024-01-01', 3),
  (1, 2, 'Bio',   '2024-02-01', 3),
  (1, 3, 'Chem',  '2024-03-01', 4),
  (1, 4, 'Dance', '2024-04-01', 4),
  (1, 5, 'Econ',  '2024-05-01', 3),
  (2, 1, 'Art',   '2024-01-01', 5),
  (2, 2, 'Bio',   '2024-02-01', 5),
  (2, 3, 'Chem',  '2024-03-01', 5);

-- expect-empty: user 1 averages 17/5 = 3.4 (< 4), user 2 has 3 courses (< 5): no top performers, no pairs
