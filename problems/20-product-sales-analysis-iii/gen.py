"""Random data for Product Sales Analysis III.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Sales rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- products = n_rows // 5 (at least 3); a few products are very popular (power-law pick), most have 1-5 rows.
- Each product has a start year (2000-2014, fixed by its id). A row's year is start + a geometric-ish
  offset (0 about half the time), so most products have SEVERAL rows in their first year and the
  rest of their rows later; some products have no row at their start year, so the first year is later.
- quantity 1..5 and price from 5 values: identical (product, year, quantity, price) rows are common,
  so the output contains duplicate rows (sale_id is not selected) and DISTINCT/GROUP BY give wrong answers.
- sale_id is sequential and independent of the year, so the smallest sale_id is not the first year.
"""
import random

PRICES = [100, 250, 500, 1000, 5000]


def _start_year(pid: int) -> int:
    return 2000 + (pid * 7919) % 15


def _sales(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-sales")
    n_products = max(3, n_rows // 5)
    for sid in range(1, n_rows + 1):
        pid = int(n_products * rng.random() ** 1.7) + 1
        year = _start_year(pid) + min(int(rng.expovariate(0.7)), 9)
        yield (sid, pid, year, rng.randint(1, 5), rng.choice(PRICES))


def generate(n_rows: int, seed: int) -> dict:
    return {"Sales": _sales(n_rows, seed)}
