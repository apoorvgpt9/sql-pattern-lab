"""Random data for Confirmation Rate.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Confirmations rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic, not to look pretty:
- Signups = n_rows // 3 users. The top 25% of user_ids never make a request (the zero-request case is common).
- Requests are skewed toward low user_ids (a few heavy users, a long tail with 1-2 requests).
- Each user has a fixed confirm probability from {0.0, 0.1, ..., 1.0}, so all-timeout, all-confirmed and
  many awkward ratios (1/3, 1/8, 5/8 ...) all occur.
- ~2% of requests belong to a user_id that is not in Signups.
- time_stamp is unique per request (the table's PK is (user_id, time_stamp)).
"""
import datetime as dt
import random

SIGNUP_START = dt.datetime(2020, 1, 1)
REQUEST_START = dt.datetime(2020, 6, 1)


def _n_users(n_rows: int) -> int:
    return max(4, n_rows // 3)


def _signups(n_users: int, seed: int):
    rng = random.Random(f"{seed}-signups")
    for uid in range(1, n_users + 1):
        yield (uid, SIGNUP_START + dt.timedelta(seconds=rng.randrange(150 * 86400)))


def _confirm_prob(uid: int) -> float:
    return ((uid * 7) % 11) / 10  # 0.0 .. 1.0 in tenths, fixed per user


def _confirmations(n_rows: int, n_users: int, seed: int):
    rng = random.Random(f"{seed}-confirmations")
    active = max(1, int(n_users * 0.75))  # ids above this never make a request
    for i in range(n_rows):
        if rng.random() < 0.02:
            uid = n_users + rng.randint(1, 1000)  # not a signup
        else:
            uid = int(active * rng.random() ** 2) + 1
        action = "confirmed" if rng.random() < _confirm_prob(uid) else "timeout"
        # unique per row, so (user_id, time_stamp) can never collide
        yield (uid, REQUEST_START + dt.timedelta(seconds=17 * i), action)


def generate(n_rows: int, seed: int) -> dict:
    n_users = _n_users(n_rows)
    return {
        "Signups": _signups(n_users, seed),
        "Confirmations": _confirmations(n_rows, n_users, seed),
    }
