"""Random data for Find Golden Hour Customers.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of restaurant_orders rows (one table).
Rows are yielded lazily, customer by customer, so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic, not to look pretty:
- Customers have 1..~30 orders (mean about 6), so many fail the 3-order minimum.
- Each customer has a fixed peak probability from {0, 0.2, 0.5, 0.6, 0.8, 1.0} and a fixed "rated" probability from
  {0.2, 0.5, 0.5, 0.8, 1.0}; with a handful of orders, shares of exactly 60% and exactly 50% occur regularly.
- Each customer has a rating mean from {3.0, 4.0, 4.0, 4.5}, ratings are clamped to 1..5, so averages of exactly 4.0 occur.
- ~10% of peak orders sit exactly on a window edge (11:00:00, 14:00:00, 18:00:00, 21:00:00) and ~10% of off-peak orders sit one
  second outside (10:59:59, 14:00:01, 17:59:59, 21:00:01): the inclusive-boundary and HOUR() traps.
"""
import datetime as dt
import random

START = dt.date(2024, 1, 1)
PEAK_P = [0.0, 0.2, 0.5, 0.6, 0.8, 1.0]
RATED_P = [0.2, 0.5, 0.5, 0.8, 1.0]
RATING_MU = [3.0, 4.0, 4.0, 4.5]
PEAK_EDGES = [dt.time(11, 0, 0), dt.time(14, 0, 0), dt.time(18, 0, 0), dt.time(21, 0, 0)]
JUST_OUTSIDE = [dt.time(10, 59, 59), dt.time(14, 0, 1), dt.time(17, 59, 59), dt.time(21, 0, 1)]
METHODS = ["cash", "card", "app"]


def _secs(t: dt.time) -> int:
    return t.hour * 3600 + t.minute * 60 + t.second


def _time_of_day(rng: random.Random, peak: bool) -> dt.time:
    if peak:
        if rng.random() < 0.10:
            return rng.choice(PEAK_EDGES)
        lo, hi = rng.choice([(11 * 3600, 14 * 3600), (18 * 3600, 21 * 3600)])
        s = rng.randint(lo, hi)
    else:
        if rng.random() < 0.10:
            return rng.choice(JUST_OUTSIDE)
        # off-peak: 00:00-10:59:58, 14:00:02-17:59:58, 21:00:02-23:59:59
        s = rng.choice([rng.randint(0, 10 * 3600 + 3598), rng.randint(14 * 3600 + 2, 17 * 3600 + 3598),
                        rng.randint(21 * 3600 + 2, 86399)])
    return dt.time(s // 3600, s % 3600 // 60, s % 60)


def generate(n_rows: int, seed: int) -> dict:
    return {"restaurant_orders": _orders(n_rows, seed)}


def _orders(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-orders")
    oid = 0
    cid = 0
    while oid < n_rows:
        cid += 1
        k = min(1 + int(rng.expovariate(1 / 5)), 30, n_rows - oid)
        peak_p = rng.choice(PEAK_P)
        rated_p = rng.choice(RATED_P)
        mu = rng.choice(RATING_MU)
        for _ in range(k):
            day = START + dt.timedelta(days=rng.randrange(366))
            ts = dt.datetime.combine(day, _time_of_day(rng, rng.random() < peak_p))
            rating = None if rng.random() > rated_p else min(5, max(1, round(rng.gauss(mu, 1.0))))
            oid += 1
            yield (oid, cid, ts, round(rng.uniform(5, 120), 2), rng.choice(METHODS), rating)
