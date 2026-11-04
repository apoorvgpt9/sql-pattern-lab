-- Approach 2: look at the neighbouring row instead of looking the partner up.
-- Odd seat -> the NEXT row's student; even seat -> the PREVIOUS row's student.
-- The last odd seat has no next row (LEAD is NULL), so COALESCE keeps its own student.
-- Correct only because ids are contiguous from 1: "next row" must mean "id + 1".
SELECT
  id,
  CASE WHEN id % 2 = 1
       THEN COALESCE(LEAD(student) OVER (ORDER BY id), student)
       ELSE LAG(student) OVER (ORDER BY id)
  END AS student
FROM Seat
ORDER BY id;
