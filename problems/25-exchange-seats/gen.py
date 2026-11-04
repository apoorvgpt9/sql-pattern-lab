"""Random data for Exchange Seats.

generate(n_rows, seed) -> {table: rows}; n_rows is the target number of seats.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Seat count is n_rows for even seeds and n_rows - 1 for odd seeds, so both parities (with and
  without an unpaired last seat) are covered by the differential test's seeds 1..5.
- ids are contiguous from 1 (a guarantee of the spec).
- Names come from a pool of about n/4 distinct names, so every name appears several times (about 4 on average,
  with a few very common ones) and any query that matches seats by name instead of by id gives wrong output.
- No NULL students: the spec says nulls are not a case.
"""
import random

FIRST = ["Ann", "Bob", "Cy", "Dee", "Eli", "Fay", "Gus", "Hana", "Ivo", "Jun", "Kai", "Lea"]


def _seats(n_seats: int, seed: int):
    rng = random.Random(f"{seed}-seats")
    pool = max(1, n_seats // 4)
    for sid in range(1, n_seats + 1):
        k = int(pool * rng.random() ** 2)  # skew: low-numbered names are common
        yield (sid, f"{FIRST[k % len(FIRST)]}{k}")


def generate(n_rows: int, seed: int) -> dict:
    n_seats = max(1, n_rows - (seed & 1))
    return {"Seat": _seats(n_seats, seed)}
