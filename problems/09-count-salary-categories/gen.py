"""Random data for Count Salary Categories.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Accounts.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Incomes are log-normal-ish (median ~ 32000): many Low and Average, a thin High tail.
- ~12% of accounts sit exactly on or next to a cut-off (19999, 20000, 50000, 50001),
  so boundary handling decides the result at every seed.
- ~2% have income NULL; ~1% have income 0.
- Heavy duplication: incomes are rounded to the nearest 100 for most accounts, so equal incomes are common
  (this catches COUNT(DISTINCT income)).
- When seed % 5 == 0 the High tail is removed (incomes capped at 50000), so the differential test (seeds 1..5)
  always includes a run where a category is empty and must come back as 0.
"""
import random

BOUNDARY = [19999, 20000, 50000, 50001]


def _accounts(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-accounts")
    cap_high = seed % 5 == 0
    for aid in range(1, n_rows + 1):
        r = rng.random()
        if r < 0.02:
            income = None
        elif r < 0.03:
            income = 0
        elif r < 0.15:
            income = rng.choice(BOUNDARY)
        else:
            income = int(rng.lognormvariate(10.4, 0.7))
            if rng.random() < 0.8:
                income = round(income, -2)
        if cap_high and income is not None and income > 50000:
            income = rng.choice([50000, 49900, 20000, 31000])
        yield (aid, income)


def generate(n_rows: int, seed: int) -> dict:
    return {"Accounts": _accounts(n_rows, seed)}
