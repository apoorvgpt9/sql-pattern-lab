"""Random data for Monthly Transactions I.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Transactions rows (one table).
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic, not to look pretty:
- 36 months (2018-2020), the same calendar months in different years (the "merge Jan 2019 with Jan 2020" trap).
- ~4% of dates fall on a first or last day of a month.
- Countries are skewed (US heavy, a long tail) and ~3% of rows have a NULL country (their own group).
- Approval probability depends on country, from 0.85 down to 0.0 ('UK' is always declined), so groups with no
  approved row occur at every size; NULL country is 50/50.
- ~3% of amounts are 0 (an approved row that adds nothing); the rest are skewed 1..1000.
"""
import datetime as dt
import random

COUNTRIES = ["US", "DE", "FR", "IN", "BR", "JP", "UK"]
WEIGHTS = [40, 18, 12, 12, 8, 6, 4]
P_APPROVED = {"US": 0.85, "DE": 0.70, "FR": 0.60, "IN": 0.50, "BR": 0.30, "JP": 0.15, "UK": 0.0, None: 0.5}
START = dt.date(2018, 1, 1)
N_DAYS = 3 * 365 + 1  # 2018-01-01 .. 2020-12-31 (2020 is a leap year)


def _month_edges():
    edges = []
    for y in (2018, 2019, 2020):
        for m in range(1, 13):
            first = dt.date(y, m, 1)
            nxt = dt.date(y + (m == 12), m % 12 + 1, 1)
            edges += [first, nxt - dt.timedelta(days=1)]
    return edges


EDGES = _month_edges()


def generate(n_rows: int, seed: int) -> dict:
    return {"Transactions": _transactions(n_rows, seed)}


def _transactions(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-transactions")
    for tid in range(1, n_rows + 1):
        country = None if rng.random() < 0.03 else rng.choices(COUNTRIES, WEIGHTS)[0]
        state = "approved" if rng.random() < P_APPROVED[country] else "declined"
        amount = 0 if rng.random() < 0.03 else int(1 + 999 * rng.random() ** 2)
        if rng.random() < 0.04:
            day = rng.choice(EDGES)
        else:
            day = START + dt.timedelta(days=rng.randrange(N_DAYS))
        yield (tid, country, state, amount, day)
