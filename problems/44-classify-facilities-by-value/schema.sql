-- Classify facilities by value (pgexercises aggregates/classify): tables for MySQL 8.0.
-- Names mirror the original; the cd. schema prefix is dropped because the harness owns the database.
-- Nullability follows the original (all NOT NULL). Foreign keys are omitted so test data can be
-- inserted in any order; the members table is not needed for this question and is not created.

CREATE TABLE bookings (
  bookid    INT      NOT NULL,
  facid     INT      NOT NULL,   -- FK facilities
  memid     INT      NOT NULL,   -- FK members; 0 = the shared GUEST account
  starttime DATETIME NOT NULL,   -- timestamp in the original
  slots     INT      NOT NULL,   -- number of 30-minute slots booked
  PRIMARY KEY (bookid)           -- grain: one row per booking
);

CREATE TABLE facilities (
  facid              INT           NOT NULL,
  name               VARCHAR(100)  NOT NULL,
  membercost         DECIMAL(10,2) NOT NULL,  -- per slot, for members
  guestcost          DECIMAL(10,2) NOT NULL,  -- per slot, for guests (memid 0)
  initialoutlay      DECIMAL(10,2) NOT NULL,
  monthlymaintenance DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (facid)            -- grain: one row per facility
);
