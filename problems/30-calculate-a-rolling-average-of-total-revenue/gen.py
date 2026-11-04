"""Random data for Calculate a rolling average of total revenue (PostgreSQL Exercises style `cd` schema).

generate(n_rows, seed) -> {table: rows}; n_rows is the number of bookings.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.
The data is synthetic: it uses the exercise's schema, not the original clubdata dump.

Distributions chosen to exercise the logic:
- 9 facilities with their own prices: five have a member price of 0 (so member bookings there earn nothing),
  and some prices have fractions (15.5, 3.5), so revenue totals are not whole numbers.
- 60% of bookings fall in 2012-06-15 .. 2012-09-15 (the neighbourhood of the queried window); the rest are spread
  over 2010-2014. At small n_rows this still leaves several August days with no booking at all, and 8% of
  the days in the dense period are "closed" (no bookings), so runs of zero-revenue days and
  windows that are entirely zero occur.
- 35% of bookings are by guests (memid 0). The other bookings are by members, skewed toward low memids.
- About 2% of bookings start exactly at 00:00 and 2% at 23:30, so day boundaries are exercised;
  all others start between 08:00 and 21:30 in half-hour steps. Slots are 1-8.
- members has memid 0 (GUEST) plus n_rows // 200 members (at least 20); recommendedby is NULL or an earlier member.
"""
import datetime as dt
import random

FACILITIES = [  # facid, name, membercost, guestcost, initialoutlay, monthlymaintenance
    (0, "Clay Court A", "6.00", "28.00", "9000", "200"),
    (1, "Clay Court B", "6.00", "28.00", "8000", "200"),
    (2, "Shuttle Hall", "0.00", "14.50", "4500", "60"),
    (3, "Ping-Pong Nook", "0.00", "4.50", "300", "10"),
    (4, "Spa Suite 1", "32.00", "75.00", "4000", "3000"),
    (5, "Spa Suite 2", "32.00", "75.00", "4000", "3000"),
    (6, "Wall Court", "3.00", "16.00", "5000", "80"),
    (7, "Cue Room 1", "0.00", "6.00", "450", "15"),
    (8, "Cue Room 2", "0.00", "6.00", "400", "15"),
]
DENSE_START, DENSE_DAYS = dt.date(2012, 6, 15), 93
WIDE_START, WIDE_DAYS = dt.date(2010, 1, 1), 5 * 365
SURNAMES = ["Okafor", "Lindqvist", "Haddad", "Costa", "Novak", "Tanaka", "Mbeki", "Silva", "Petrov", "Dubois"]
GIVEN = ["Ife", "Mats", "Rima", "Ines", "Jana", "Kenji", "Zola", "Ana", "Ivo", "Lea"]


def _n_members(n_rows: int) -> int:
    return max(20, n_rows // 200)


def _members(n_members: int, seed: int):
    rng = random.Random(f"{seed}-members")
    yield (0, "GUEST", "GUEST", "GUEST", 0, "000-0000", None, dt.datetime(2010, 1, 1))
    for memid in range(1, n_members + 1):
        rec = None if rng.random() < 0.5 else rng.randint(0, memid - 1)
        joined = dt.datetime(2010, 1, 1) + dt.timedelta(days=rng.randrange(900), minutes=30 * rng.randrange(48))
        yield (memid, rng.choice(SURNAMES), rng.choice(GIVEN), f"{rng.randint(1, 99)} Elm Road",
               10000 + rng.randrange(900), f"555-{rng.randrange(10000):04d}", rec, joined)


def _facilities():
    for facid, name, mc, gc, outlay, maint in FACILITIES:
        yield (facid, name, mc, gc, outlay, maint)


def _bookings(n_rows: int, n_members: int, seed: int):
    rng = random.Random(f"{seed}-bookings")
    closed = {d for d in range(DENSE_DAYS) if random.Random(f"{seed}-closed-{d}").random() < 0.08}
    for bookid in range(1, n_rows + 1):
        while True:
            if rng.random() < 0.60:
                offset = rng.randrange(DENSE_DAYS)
                if offset in closed:
                    continue
                day = DENSE_START + dt.timedelta(days=offset)
            else:
                day = WIDE_START + dt.timedelta(days=rng.randrange(WIDE_DAYS))
            break
        r = rng.random()
        if r < 0.02:
            clock = dt.timedelta(0)
        elif r < 0.04:
            clock = dt.timedelta(hours=23, minutes=30)
        else:
            clock = dt.timedelta(hours=8, minutes=30 * rng.randrange(28))
        memid = 0 if rng.random() < 0.35 else 1 + int(n_members * rng.random() ** 2)
        yield (bookid, rng.randrange(len(FACILITIES)), memid,
               dt.datetime.combine(day, dt.time()) + clock, rng.randint(1, 8))


def generate(n_rows: int, seed: int) -> dict:
    n_members = _n_members(n_rows)
    return {
        "members": _members(n_members, seed),
        "facilities": _facilities(),
        "bookings": _bookings(n_rows, n_members, seed),
    }
