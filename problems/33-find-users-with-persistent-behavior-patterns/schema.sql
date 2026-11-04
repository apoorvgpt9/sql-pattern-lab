-- Find Users with Persistent Behavior Patterns (LeetCode 3832): tables for MySQL 8.0. Names mirror the original.
-- The primary key allows several actions by one user on one day; those days are what the
-- "exactly one action per day" rule removes.

CREATE TABLE activity (
  user_id     INT,
  action_date DATE,
  action      VARCHAR(100),
  PRIMARY KEY (user_id, action_date, action)   -- grain: one (user, day, action)
);
