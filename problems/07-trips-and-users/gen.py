"""Random data for Trips and Users.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Trips rows (the main table).
Tables are returned Users first. Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic, not to look pretty:
- Users = about n_rows / 4. User ids come in blocks of 20: ids with (id-1) % 20 < 9 are clients, < 18 are drivers, the
  rest partners. ~6% of users are banned (decided by a hash of the id), on every side, so many trips have exactly one
  banned party, a few have two, and on small inputs some whole days have no eligible trip.
- Trips pick a client and a driver with a skew toward low ids (a few heavy users), so banned heavy users matter.
- Status: 70% completed, 15% cancelled_by_driver, 15% cancelled_by_client.
- request_at spans 2013-09-16 .. 2013-10-15 (30 days, so the 3-day query range is a 10% slice and a range scan on
  request_at pays off at scale); ~6% of trips land exactly on 2013-09-30, 2013-10-01, 2013-10-03 or 2013-10-04, the day
  boundaries of the range.
- Every client_id / driver_id exists in Users (the foreign key holds).
"""
import datetime as dt
import random

FIRST_DAY = dt.date(2013, 9, 16)
N_DAYS = 30
BOUNDARY_DAYS = [dt.date(2013, 9, 30), dt.date(2013, 10, 1), dt.date(2013, 10, 3), dt.date(2013, 10, 4)]


def _n_blocks(n_rows: int) -> int:
    return max(2, n_rows // 80)  # 20 users per block -> about n_rows / 4 users


def _banned(uid: int) -> str:
    return "Yes" if (uid * 7919) % 100 < 6 else "No"


def _users(n_blocks: int):
    for uid in range(1, 20 * n_blocks + 1):
        r = (uid - 1) % 20
        role = "client" if r < 9 else "driver" if r < 18 else "partner"
        yield (uid, _banned(uid), role)


def _trips(n_rows: int, n_blocks: int, seed: int):
    rng = random.Random(f"{seed}-trips")
    for tid in range(1, n_rows + 1):
        client = 20 * int(n_blocks * rng.random() ** 2) + rng.randrange(9) + 1
        driver = 20 * int(n_blocks * rng.random() ** 2) + 9 + rng.randrange(9) + 1
        r = rng.random()
        status = "completed" if r < 0.70 else "cancelled_by_driver" if r < 0.85 else "cancelled_by_client"
        if rng.random() < 0.06:
            day = rng.choice(BOUNDARY_DAYS)
        else:
            day = FIRST_DAY + dt.timedelta(days=rng.randrange(N_DAYS))
        yield (tid, client, driver, rng.randint(1, 20), status, day.isoformat())


def generate(n_rows: int, seed: int) -> dict:
    n_blocks = _n_blocks(n_rows)
    return {"Users": _users(n_blocks), "Trips": _trips(n_rows, n_blocks, seed)}
