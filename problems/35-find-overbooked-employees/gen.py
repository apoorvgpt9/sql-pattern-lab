"""Random data for Find Overbooked Employees.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of meetings rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- employees = n_rows // 15. Each employee gets a run of weeks; per week, 1-6 meetings whose
  durations are drawn so the weekly total clusters around 20 hours (the boundary). ~6% of weeks are
  forced to sum to exactly 20.00.
- Weeks are emitted per employee from a random Monday; meeting days span Monday..Sunday, so
  Sunday meetings are common, and starting dates near late December make weeks cross the new year.
- Durations are multiples of 0.25 h; ~1% are NULL. ~2% of meetings reference an employee_id not in
  employees. ~10% of employees have no meetings.
- Names come from a small pool, so the ordering key employee_name ties often.
"""
import datetime as dt
import random

NAMES = ["Ada", "Ben", "Cai", "Dee", "Eli", "Fay", "Gus", "Hana", "Ivo", "Jun"]
DEPTS = ["Eng", "Sales", "Ops", "Legal", "Finance", None]
TYPES = ["Team", "Client", "Training"]
MONDAYS = [dt.date(2023, 12, 18), dt.date(2024, 12, 16), dt.date(2024, 3, 4), dt.date(2025, 6, 2)]


def _employees(n_emp: int, seed: int):
    rng = random.Random(f"{seed}-employees")
    for eid in range(1, n_emp + 1):
        yield (eid, rng.choice(NAMES), rng.choice(DEPTS))


def _quarters(total_q: int, k: int, rng):
    """Split total_q quarter-hours into k positive parts."""
    if k == 1 or total_q < k:
        return [total_q]
    cuts = sorted(rng.sample(range(1, total_q), k - 1))
    return [b - a for a, b in zip([0] + cuts, cuts + [total_q])]


def _meetings(n_rows: int, n_emp: int, seed: int):
    rng = random.Random(f"{seed}-meetings")
    mid = 0
    while mid < n_rows:
        eid = n_emp + rng.randint(1, 50) if rng.random() < 0.02 else rng.randint(1, max(1, int(n_emp * 0.9)))
        monday = rng.choice(MONDAYS) + dt.timedelta(weeks=rng.randrange(4))
        for _ in range(rng.randint(1, 6)):          # weeks for this employee
            r = rng.random()
            week_total_q = 80 if r < 0.06 else rng.randint(40, 120)   # quarter-hours; 80 = 20.00 h
            k = rng.randint(1, 6)
            for part in _quarters(week_total_q, k, rng):
                if mid >= n_rows:
                    return
                mid += 1
                day = monday + dt.timedelta(days=rng.choice([0, 1, 2, 3, 4, 5, 6, 6]))
                hours = None if rng.random() < 0.01 else part / 4
                yield (mid, eid, day, rng.choice(TYPES), hours)
            monday += dt.timedelta(weeks=rng.choice([1, 1, 1, 2]))


def generate(n_rows: int, seed: int) -> dict:
    n_emp = max(3, n_rows // 15)
    return {
        "employees": _employees(n_emp, seed),
        "meetings": _meetings(n_rows, n_emp, seed),
    }
