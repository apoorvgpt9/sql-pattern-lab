-- Nothing qualifies: a decline, an equal pair and a single exam.
INSERT INTO Scores (student_id, subject, score, exam_date) VALUES
  (1, 'Math', 80, '2024-01-01'),
  (1, 'Math', 70, '2024-02-01'),
  (2, 'Math', 50, '2024-01-01'),
  (2, 'Math', 50, '2024-02-01'),
  (3, 'Math', 90, '2024-01-01');

-- expect-empty: 1/Math fell, 2/Math is equal (strictly higher is required), 3/Math has only one exam
