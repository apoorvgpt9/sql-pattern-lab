"""Random data for Find Students Who Improved.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Scores rows.
Rows are yielded lazily, one (student, subject) pair at a time, so n_rows=1_000_000 streams
without building lists; the last pair is truncated to hit n_rows exactly.

Distributions chosen to exercise the logic:
- Each student sits a random half of 8 subjects. A pair has 1-6 exams (1 exam about a quarter of
  the time), on distinct days between 2023-01-01 and 2024-12-31 (the PK), so exams of one pair often
  straddle a year end and a month 9 -> 10 boundary.
- Scores follow a random walk (steps -15..+15 with 20% zero steps, clipped to 0..100), so about 40%
  of pairs improve, ~40% decline, and a visible share end exactly where they began (equal first and
  latest score), including peaks and dips in the middle.
- Rows of a pair are yielded in shuffled order, so physical order never equals chronological order.
"""
import datetime as dt
import random

SUBJECTS = ["Art", "Biology", "Chemistry", "English", "History", "Math", "Music", "Physics"]
START = dt.date(2023, 1, 1)
SPAN = 2 * 365


def _pairs(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-scores")
    left, student = n_rows, 0
    while left > 0:
        student += 1
        for subject in SUBJECTS:
            if left <= 0:
                break
            if rng.random() < 0.5:
                continue
            k = min(rng.choices(range(1, 7), [25, 25, 20, 15, 10, 5])[0], left)
            left -= k
            offsets = sorted(rng.sample(range(SPAN), k))
            score = rng.randint(30, 90)
            rows = []
            for off in offsets:
                rows.append((student, subject, score, (START + dt.timedelta(days=off)).isoformat()))
                step = 0 if rng.random() < 0.2 else rng.randint(-15, 15)
                score = max(0, min(100, score + step))
            rng.shuffle(rows)
            yield from rows


def generate(n_rows: int, seed: int) -> dict:
    return {"Scores": _pairs(n_rows, seed)}
