"""Random data for Human Traffic of Stadium.

generate(n_rows, seed) -> {"Stadium": rows}; n_rows is the number of Stadium rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Attendance alternates between "busy" and "quiet" stretches whose lengths are drawn so that runs
  of length 1, 2, 3 (the boundary) and 4-12 are all common.
- ~5% of busy days have exactly 100 people, ~5% of quiet days exactly 99 (the >= 100 boundary).
- ~1% of people values are NULL (an unknown count must break a run).
- ~2% of ids are skipped (the next id is +2), so consecutive dates do not always mean consecutive ids;
  visit_date sometimes skips days too, so consecutive ids do not always mean consecutive dates.
"""
import datetime as dt
import random

START = dt.date(2015, 1, 1)


def _stadium(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-stadium")
    vid, day = 0, START
    busy = rng.random() < 0.5
    left = 0
    for _ in range(n_rows):
        if left == 0:
            busy = not busy
            if busy:
                left = rng.choice([1, 1, 2, 2, 3, 3, 3, 4, 5, 6, 8, 12])
            else:
                left = rng.choice([1, 1, 1, 2, 3])
        left -= 1
        vid += 2 if rng.random() < 0.02 else 1
        day += dt.timedelta(days=2 if rng.random() < 0.05 else 1)
        r = rng.random()
        if r < 0.01:
            people = None
        elif busy:
            people = 100 if r < 0.06 else rng.randint(100, 5000)
        else:
            people = 99 if r < 0.06 else rng.randint(0, 99)
        yield (vid, day, people)


def generate(n_rows: int, seed: int) -> dict:
    return {"Stadium": _stadium(n_rows, seed)}
