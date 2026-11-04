-- Find Churn Risk Customers (LeetCode 3716): tables for MySQL 8.0. Names mirror the original.

CREATE TABLE subscription_events (
  event_id       INT PRIMARY KEY,   -- grain: one row per subscription event
  user_id        INT,
  event_date     DATE,
  event_type     VARCHAR(20),       -- 'start' | 'upgrade' | 'downgrade' | 'cancel'
  plan_name      VARCHAR(20),       -- 'basic' | 'standard' | 'premium'; NULL on cancel
  monthly_amount DECIMAL(10,2)      -- 0 on cancel
);
