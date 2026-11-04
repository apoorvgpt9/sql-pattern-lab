-- ASSUMPTION (README "Assumptions"): the spec does not say what happens when one user completes two courses on the
-- same date. We break the tie by course_id (smaller id first). Here Zeta (20) and Beta (30) share 2024-02-01;
-- their names are in the opposite alphabetical order to their ids, so a name-based tie-break gives a different answer.
INSERT INTO course_completions (user_id, course_id, course_name, completion_date, course_rating) VALUES
  (1, 10, 'Alpha', '2024-01-01', 5),
  (1, 20, 'Zeta',  '2024-02-01', 5),
  (1, 30, 'Beta',  '2024-02-01', 5),
  (1, 40, 'Omega', '2024-03-01', 5),
  (1, 50, 'Sigma', '2024-04-01', 5);

-- Order by (completion_date, course_id): Alpha, Zeta, Beta, Omega, Sigma
-- expect: Alpha,Zeta,1 | Alpha (Jan) then Zeta (id 20 sorts before id 30 on the shared date)
-- expect: Beta,Omega,1 | Beta is the second course on the shared date, so it is followed by Omega
-- expect: Omega,Sigma,1 | last pair
-- expect: Zeta,Beta,1 | the two same-day courses in id order: Zeta (20) then Beta (30)
