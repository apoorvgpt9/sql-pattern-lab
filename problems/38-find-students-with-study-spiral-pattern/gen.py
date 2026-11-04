"""Random data for Find Students with Study Spiral Pattern.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of study_sessions rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic. Each student is one of these profiles:
- ~35% perfect spirals: k = 3-5 subjects, 2-4 full cycles, gaps of 0-2 days (some exactly 2,
  some 0 = two sessions on one day, ordered by session_id).
- ~45% near misses, one defect each: a partial trailing cycle, one swapped subject, a single
  3-day gap, k = 2, a repeated block like A,B,A,C (k = 3 but the count is not a multiple of 3),
  or only one cycle.
- ~20% random histories (random subjects, random gaps).
- session_ids are assigned in a shuffled order within a student, so session_id order differs
  from date order; ~3% of sessions belong to student ids that are not in students.
- hours are multiples of 0.5, ~2% NULL. Subject pools overlap across students.
"""
import datetime as dt
import random

SUBJECTS = ["Math", "Physics", "Chem", "Bio", "History", "Art", "Music", "Law"]
MAJORS = ["CS", "EE", "Bio", "Law", None]
NAMES = ["Ann", "Ben", "Cy", "Dia", "Eve", "Fox", "Gia", "Hal", "Ivy", "Jo"]


def _sequence(rng):
    """Return a list of (subject, gap_days) for one student."""
    kind = rng.random()
    k = rng.choice([3, 3, 4, 5])
    cycle = rng.sample(SUBJECTS, k)
    subjects = cycle * rng.choice([2, 2, 3, 4])
    gaps = [rng.choice([0, 1, 1, 1, 2, 2]) for _ in subjects]
    if kind < 0.35:
        pass
    elif kind < 0.80:
        defect = rng.choice(["partial", "swap", "gap", "k2", "block", "one_cycle"])
        if defect == "partial":
            subjects = subjects + cycle[: rng.randint(1, k - 1)]
            gaps = gaps + [1] * (len(subjects) - len(gaps))
        elif defect == "swap":
            i = rng.randrange(k, len(subjects) - 1)
            subjects[i], subjects[i + 1] = subjects[i + 1], subjects[i]
        elif defect == "gap":
            gaps[rng.randrange(1, len(gaps))] = 3
        elif defect == "k2":
            subjects = cycle[:2] * rng.choice([2, 3, 4])
            gaps = [1] * len(subjects)
        elif defect == "block":
            a, b, c = cycle[:3]
            subjects = [a, b, a, c] * rng.choice([2, 3])
            gaps = [1] * len(subjects)
        else:
            subjects = list(cycle)
            gaps = [1] * len(subjects)
    else:
        n = rng.randint(1, 12)
        subjects = [rng.choice(SUBJECTS[:5]) for _ in range(n)]
        gaps = [rng.choice([0, 1, 2, 3, 5]) for _ in range(n)]
    return list(zip(subjects, gaps))


def _data(n_rows: int, seed: int, n_students_out: list):
    rng = random.Random(f"{seed}-sessions")
    sid, student = 0, 0
    while sid < n_rows:
        student += 1
        owner = student if rng.random() > 0.03 else 10_000_000 + student  # ~3% unknown students
        seq = _sequence(rng)
        d = dt.date(2024, 1, 1) + dt.timedelta(days=rng.randrange(300))
        rows = []
        for i, (subject, gap) in enumerate(seq):
            if i:
                d += dt.timedelta(days=gap)
            hours = None if rng.random() < 0.02 else rng.randint(1, 8) / 2
            rows.append([owner, subject, d, hours])
        # session_id must follow date order on different days but may be in any order within a
        # day; shuffle ids within each day so the (session_date, session_id) tiebreak matters.
        ids = list(range(sid + 1, sid + 1 + len(rows)))
        by_day = {}
        for idx, r in enumerate(rows):
            by_day.setdefault(r[2], []).append(idx)
        order = []
        for day in sorted(by_day):
            order.extend(by_day[day])
        # rows in (date, intended position) order get ascending ids
        for new_id, idx in zip(ids, order):
            rows[idx].insert(0, new_id)
        # but occasionally give a later-day session a SMALLER id than an earlier day (ids are not
        # chronological in general): swap the ids of two sessions on different days
        if len(rows) > 3 and rng.random() < 0.3:
            i, j = rng.sample(range(len(rows)), 2)
            if rows[i][3] != rows[j][3]:
                rows[i][0], rows[j][0] = rows[j][0], rows[i][0]
        for r in sorted(rows, key=lambda r: r[0]):
            if sid >= n_rows:
                break
            sid += 1
            yield (r[0], r[1], r[2], r[3], r[4])
    n_students_out.append(student)


def generate(n_rows: int, seed: int) -> dict:
    n_students = max(3, n_rows // 6)
    rng = random.Random(f"{seed}-students")

    def students():
        for i in range(1, n_students + 1):
            yield (i, rng.choice(NAMES), rng.choice(MAJORS))

    return {"students": students(), "study_sessions": _data(n_rows, seed, [])}
