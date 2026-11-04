-- Users 1 and 2 are top performers (5 courses, average rating 4.4). User 3 has 4 courses, all rated 5:
-- an excellent average but too few courses. course_id is a property of the course (SQL = 10, Python = 20, ...)
-- and does NOT follow completion order for user 2 (dbt, id 50, is completed before Spark, id 30).
INSERT INTO course_completions (user_id, course_id, course_name, completion_date, course_rating) VALUES
  (1, 10, 'SQL',     '2024-01-05', 5),
  (1, 20, 'Python',  '2024-02-05', 4),
  (1, 30, 'Spark',   '2024-03-05', 4),
  (1, 40, 'Airflow', '2024-04-05', 5),
  (1, 50, 'dbt',     '2024-05-05', 4),   -- user 1: 22/5 = 4.4
  (2, 10, 'SQL',     '2024-01-10', 4),
  (2, 20, 'Python',  '2024-02-10', 4),
  (2, 50, 'dbt',     '2024-03-10', 5),
  (2, 30, 'Spark',   '2024-04-10', 5),
  (2, 60, 'Kafka',   '2024-05-10', 4),   -- user 2: 22/5 = 4.4
  (3, 10, 'SQL',     '2024-01-01', 5),
  (3, 20, 'Python',  '2024-01-02', 5),
  (3, 30, 'Spark',   '2024-01-03', 5),
  (3, 60, 'Kafka',   '2024-01-04', 5);   -- user 3: only 4 courses

-- User 1 in date order: SQL, Python, Spark, Airflow, dbt -> SQL>Python, Python>Spark, Spark>Airflow, Airflow>dbt
-- User 2 in date order: SQL, Python, dbt, Spark, Kafka    -> SQL>Python, Python>dbt, dbt>Spark, Spark>Kafka
-- expect: SQL,Python,2 | users 1 and 2 both go SQL -> Python; the only pair seen twice, so first
-- expect: Airflow,dbt,1 | user 1 only; the count-1 rows are ordered by first_course then second_course ('Airflow' < 'dbt' < 'Python' < 'Spark')
-- expect: dbt,Spark,1 | user 2 only (dbt completed before Spark); user 1 never goes dbt > Spark
-- expect: Python,dbt,1 | user 2 only; 'dbt' sorts before 'Spark'
-- expect: Python,Spark,1 | user 1 only
-- expect: Spark,Airflow,1 | user 1 only
-- expect: Spark,Kafka,1 | user 2 only; user 3's Spark > Kafka does not count (not a top performer)
