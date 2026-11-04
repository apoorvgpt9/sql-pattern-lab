"""Random data for Restaurant Growth.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Customer rows (customer visits).
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- About n_rows // 30 consecutive days (at least 10), starting 2019-01-01 and crossing month, year and leap-day
  boundaries. Every day has at least one customer (a guarantee of the spec: no date gaps).
- Visits per day vary between 0.3x and 1.7x of the average (so daily totals differ a lot) and a customer visits
  at most once per day (the primary key). Customer ids come from a pool 3x the average visits per day.
- Amounts are skewed: many small, a long tail of large ones (exponential), at least 1. Totals for a window are
  usually not divisible by 7, so rounding is exercised.
"""
import datetime as dt
import random

START = dt.date(2019, 1, 1)


def _visits(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-visits")
    n_days = max(10, n_rows // 30)
    base = max(1, n_rows // n_days)
    pool = max(60, base * 3)
    emitted, day = 0, 0
    while emitted < n_rows:
        count = min(max(1, int(base * rng.uniform(0.3, 1.7))), n_rows - emitted, pool)
        d = START + dt.timedelta(days=day)
        for cid in sorted(rng.sample(range(1, pool + 1), count)):
            yield (cid, f"C{cid}", d, 1 + int(rng.expovariate(1 / 60)))
        emitted += count
        day += 1


def generate(n_rows: int, seed: int) -> dict:
    return {"Customer": _visits(n_rows, seed)}
