-- Calculate a rolling average of total revenue (PostgreSQL Exercises, aggregates/rollingavg): tables for MySQL 8.0.
-- Adapted from PostgreSQL Exercises by Alisdair Owens (pgexercises.com), CC BY-SA 3.0. Spec reworded. See LICENSE.md.
-- The original lives in schema cd (cd.bookings, ...); here the prefix is dropped (one database per test run).
-- Column names mirror the original. MySQL: timestamp -> DATETIME, numeric -> DECIMAL(10,2).

CREATE TABLE members (
  memid         INT PRIMARY KEY,      -- grain: one row per member; memid 0 is the shared GUEST account
  surname       VARCHAR(200),
  firstname     VARCHAR(200),
  address       VARCHAR(300),
  zipcode       INT,
  telephone     VARCHAR(20),
  recommendedby INT,                  -- nullable; refers to members.memid
  joindate      DATETIME
);

CREATE TABLE facilities (
  facid              INT PRIMARY KEY, -- grain: one row per facility
  name               VARCHAR(100),
  membercost         DECIMAL(10,2),   -- cost per half-hour slot for members
  guestcost          DECIMAL(10,2),   -- cost per half-hour slot for guests
  initialoutlay      DECIMAL(10,2),
  monthlymaintenance DECIMAL(10,2)
);

CREATE TABLE bookings (
  bookid    INT PRIMARY KEY,          -- grain: one row per booking
  facid     INT,                      -- refers to facilities.facid
  memid     INT,                      -- refers to members.memid; 0 = guest
  starttime DATETIME,
  slots     INT                       -- number of 30-minute slots booked
);
