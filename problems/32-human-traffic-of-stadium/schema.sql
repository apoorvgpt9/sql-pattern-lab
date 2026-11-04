-- Human Traffic of Stadium (LeetCode 601): tables for MySQL 8.0. Names mirror the original.
-- As on LeetCode, id carries no constraint: it is unique in practice (autoincrement) and increases
-- with visit_date. visit_date is declared unique, as the original describes it.
-- indexes.sql adds PRIMARY KEY (id) for the "with indexes" bench run.

CREATE TABLE Stadium (
  id         INT,            -- grain: one row per visit day
  visit_date DATE,
  people     INT,
  UNIQUE KEY uq_stadium_visit_date (visit_date)
);
