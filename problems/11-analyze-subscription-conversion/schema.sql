-- Analyze Subscription Conversion (LeetCode 3497): tables for MySQL 8.0. Names mirror the original.
-- activity_type holds 'free_trial', 'paid' or 'cancelled'. Spec says nulls: n/a, so every column is NOT NULL.

CREATE TABLE UserActivity (
  user_id           INT         NOT NULL,
  activity_date     DATE        NOT NULL,
  activity_type     VARCHAR(20) NOT NULL,
  activity_duration INT         NOT NULL,   -- minutes that day
  PRIMARY KEY (user_id, activity_date, activity_type)   -- grain: one row per (user, day, type)
);
