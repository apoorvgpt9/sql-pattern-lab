-- Tests the output order (transition_count DESC, first_course ASC, second_course ASC) together with the
-- pair semantics: pairs are ORDERED (Intro>Algebra is not Algebra>Intro), and pairs are counted by course NAME
-- ('Intro' is course 1 and also course 2, two editions with one name).
-- All three users are top performers (5 courses, all rated 5).
INSERT INTO course_completions (user_id, course_id, course_name, completion_date, course_rating) VALUES
  (1, 1, 'Intro',   '2024-01-01', 5),
  (1, 3, 'Algebra', '2024-02-01', 5),
  (1, 2, 'Intro',   '2024-03-01', 5),
  (1, 4, 'Basics',  '2024-04-01', 5),
  (1, 5, 'Calc',    '2024-05-01', 5),
  (2, 2, 'Intro',   '2024-01-01', 5),
  (2, 3, 'Algebra', '2024-02-01', 5),
  (2, 1, 'Intro',   '2024-03-01', 5),
  (2, 5, 'Calc',    '2024-04-01', 5),
  (2, 4, 'Basics',  '2024-05-01', 5),
  (3, 3, 'Algebra', '2024-01-01', 5),
  (3, 4, 'Basics',  '2024-02-01', 5),
  (3, 5, 'Calc',    '2024-03-01', 5),
  (3, 1, 'Intro',   '2024-04-01', 5),
  (3, 2, 'Intro',   '2024-05-01', 5);

-- User 1: Intro>Algebra, Algebra>Intro, Intro>Basics, Basics>Calc
-- User 2: Intro>Algebra, Algebra>Intro, Intro>Calc,   Calc>Basics   (Intro is course 2 first, then course 1)
-- User 3: Algebra>Basics, Basics>Calc, Calc>Intro,    Intro>Intro   (course 1 then course 2: same name twice)
-- expect: Algebra,Intro,2 | users 1 and 2; count 2 rows come first, ordered by first_course (Algebra, Basics, Intro)
-- expect: Basics,Calc,2 | users 1 and 3
-- expect: Intro,Algebra,2 | users 1 and 2, via course 1 for user 1 and course 2 for user 2: one pair because pairs are by name
-- expect: Algebra,Basics,1 | user 3; count-1 rows ordered by first_course then second_course
-- expect: Calc,Basics,1 | user 2; the reverse of Basics>Calc, which is a different pair
-- expect: Calc,Intro,1 | user 3; second_course breaks the tie with Calc,Basics ('Basics' < 'Intro')
-- expect: Intro,Basics,1 | user 1; among the Intro-first rows: 'Basics' < 'Calc' < 'Intro'
-- expect: Intro,Calc,1 | user 2
-- expect: Intro,Intro,1 | user 3 completed course 1 then course 2, both named Intro: a pair with identical names is valid
