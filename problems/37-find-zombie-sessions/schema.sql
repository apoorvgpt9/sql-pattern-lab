-- Find Zombie Sessions (LeetCode 3673): tables for MySQL 8.0. Names mirror the original.

CREATE TABLE app_events (
  event_id        INT PRIMARY KEY,  -- grain: one row per event
  user_id         INT,
  event_timestamp DATETIME,
  event_type      VARCHAR(20),      -- 'app_open' | 'click' | 'scroll' | 'purchase' | 'app_close'
  session_id      VARCHAR(20),
  event_value     INT               -- purchase amount / scroll pixels / NULL
);
