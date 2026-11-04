-- Approach 1 (brute force): for each person, add up the weights of everyone whose turn is <= theirs (a self-join),
-- keep the people whose prefix total fits, and take the one with the largest turn.
SELECT q1.person_name
FROM Queue q1
JOIN Queue q2 ON q2.turn <= q1.turn
GROUP BY q1.person_id, q1.turn, q1.person_name
HAVING SUM(q2.weight) <= 1000
ORDER BY q1.turn DESC
LIMIT 1;
