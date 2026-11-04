"""Random data for Odd and Even Transactions.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of transactions.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Days: n_rows // 20 distinct dates (about 20 transactions per day) drawn from a ~3-year window, so
  the groups are big enough for sums to matter, plus ~3% of transactions that each sit alone on a
  date after the window. Those singleton days are always "only odd", "only even" or "only NULL",
  so the missing-side-is-0 logic is exercised at every seed and size.
- ~8% of amounts are negative, ~3% are exactly 0, ~2% are NULL.
- Amounts are skewed: most are small (many repeats of the same value on one day, so SUM DISTINCT is
  caught), a few are large.
- transaction_ids are shuffled relative to dates, so id order is unrelated to date order.
"""
import datetime as dt
import random

START = dt.date(2022, 1, 1)
WINDOW_DAYS = 3 * 365


def _transactions(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-transactions")
    n_days = max(2, n_rows // 20)
    days = [START + dt.timedelta(days=d) for d in rng.sample(range(WINDOW_DAYS), min(n_days, WINDOW_DAYS))]
    lonely = 0
    for tid in range(1, n_rows + 1):
        r = rng.random()
        if r < 0.02:
            amount = None
        elif r < 0.05:
            amount = 0
        else:
            amount = int(rng.paretovariate(1.5) * 10) if rng.random() < 0.9 else rng.randint(1, 100_000)
            if rng.random() < 0.08:
                amount = -amount
        if rng.random() < 0.03:
            lonely += 1
            day = START + dt.timedelta(days=WINDOW_DAYS + lonely)
        else:
            day = days[int(len(days) * rng.random() ** 1.5)]
        yield (tid, amount, day)


def generate(n_rows: int, seed: int) -> dict:
    return {"transactions": _transactions(n_rows, seed)}
