"""Random data for Find Consistently Improving Employees.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of performance_reviews rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic, not to look pretty:
- employees = n_rows // 5 + 1. Review counts per employee: 5% have 0, 12% have 1-2, 8% have exactly 3,
  the rest 4-14, so the ">= 3 reviews" boundary and "last three of a longer history" are both common.
- Each employee gets a trend: 35% rising (random walk up, clipped to 1..5), 15% flat, 15% falling, 35% random.
  Flat steps are therefore common, and strictly rising last-three runs are too (a few percent of employees).
- Dates are drawn WITH replacement from a 4-year range, so a few reviews per thousand share a date with another
  review of the same employee and the review_id tie-break decides which is newer.
- review_ids are assigned in a shuffled order within each employee, so review_id order is not date order.
- ~1.5% of reviews belong to employee ids that are not in employees; names are drawn from a small pool,
  so many employees share a name.
"""
import datetime as dt
import random

START = dt.date(2020, 1, 1)
SPAN_DAYS = 4 * 365
FIRST = ["Alice", "Bob", "Carol", "Dan", "Eve", "Frank", "Grace", "Heidi", "Ivan", "Judy", "Ken", "Lara"]
LAST = ["Nguyen", "Smith", "Garcia", "Kim", "Patel", "Brown", "Rossi", "Khan", "Silva", "Ito"]


def _n_employees(n_rows: int) -> int:
    return n_rows // 5 + 1


def _employees(n_emp: int, seed: int):
    rng = random.Random(f"{seed}-employees")
    for eid in range(1, n_emp + 1):
        yield (eid, f"{rng.choice(FIRST)} {rng.choice(LAST)}")


def _review_count(rng: random.Random) -> int:
    r = rng.random()
    if r < 0.05:
        return 0
    if r < 0.17:
        return rng.randint(1, 2)
    if r < 0.25:
        return 3
    return rng.randint(4, 14)


def _ratings(rng: random.Random, k: int):
    trend = rng.random()
    cur = rng.randint(1, 5)
    for _ in range(k):
        yield cur
        if trend < 0.35:
            cur = min(5, cur + rng.choice((0, 1, 1, 2)))
        elif trend < 0.50:
            pass
        elif trend < 0.65:
            cur = max(1, cur - rng.choice((0, 1, 1, 2)))
        else:
            cur = rng.randint(1, 5)


def _reviews(n_rows: int, n_emp: int, seed: int):
    rng = random.Random(f"{seed}-reviews")
    review_id, emitted, eid = 0, 0, 0
    while emitted < n_rows:
        eid += 1
        if eid > n_emp:
            employee_id = n_emp + 1 + (eid % 50)   # reviews for unknown employees
        else:
            employee_id = eid
        if rng.random() < 0.015 and eid <= n_emp:
            employee_id = n_emp + 1 + (eid % 50)
        k = min(_review_count(rng), n_rows - emitted)
        days = sorted(rng.randrange(SPAN_DAYS) for _ in range(k))
        rows = list(zip(days, _ratings(rng, k)))
        rng.shuffle(rows)  # ids are assigned in shuffled order, so id order is not date order
        for day, rating in rows:
            review_id += 1
            yield (review_id, employee_id, START + dt.timedelta(days=day), rating)
        emitted += k


def generate(n_rows: int, seed: int) -> dict:
    n_emp = _n_employees(n_rows)
    return {
        "employees": _employees(n_emp, seed),
        "performance_reviews": _reviews(n_rows, n_emp, seed),
    }
