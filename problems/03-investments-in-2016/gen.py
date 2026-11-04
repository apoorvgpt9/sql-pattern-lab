"""Random data for Investments in 2016.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Insurance rows (one table).
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic, not to look pretty:
- tiv_2015 is drawn from a pool the size of the table, so about 63% of policies share it with at least one
  other and about 37% are unique; ~3% are NULL.
- (lat, lon) is drawn from a grid with about 2x as many cells as rows: most pairs are unique, a good share are
  duplicated, and many rows share only a lat or only a lon with someone (the "each coordinate is not the pair" trap).
- tiv_2016 is a multiple of 0.25 in [0, 10000]; ~3% NULL.
- All money/coordinate values are multiples of 0.25 or 0.5, which FLOAT stores exactly, and sums of them are
  exact in DOUBLE, so every solution returns the identical sum regardless of summation order.
"""
import math
import random


def generate(n_rows: int, seed: int) -> dict:
    return {"Insurance": _insurance(n_rows, seed)}


def _insurance(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-insurance")
    pool = max(2, n_rows)                       # tiv_2015 pool
    side = max(2, math.ceil(math.sqrt(2 * n_rows)))  # grid is side x side >= 2n cells
    for pid in range(1, n_rows + 1):
        tiv15 = None if rng.random() < 0.03 else rng.randrange(pool) / 4
        tiv16 = None if rng.random() < 0.03 else rng.randrange(40001) / 4
        lat = rng.randrange(side) / 2
        lon = rng.randrange(side) / 2
        yield (pid, tiv15, tiv16, lat, lon)
