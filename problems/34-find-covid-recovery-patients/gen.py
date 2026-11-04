"""Random data for Find COVID Recovery Patients.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of covid_tests rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- patients = n_rows // 4; each patient gets a test history that is a short random walk over
  Negative / Positive / Inconclusive, so many patients have negatives before their first positive,
  several positives, and several negatives after.
- ~20% of patients are never positive, ~15% never test negative after their first positive.
- Tests often fall on the same day as the previous one (~10%), so "strictly after" matters.
- ~1% of test dates are NULL; ~2% of tests reference a patient_id not in patients.
- Names repeat (a small pool), and recovery times cluster on a few values, so the ordering keys
  recovery_time and patient_name both tie often (test_differential compares as a multiset).
- ~3% NULL age. Test volume per patient is skewed (a few heavy patients).
"""
import datetime as dt
import random

NAMES = ["Ana", "Ben", "Cho", "Dev", "Eli", "Fen", "Gia", "Hugo", "Ines", "Jon", "Kai", "Lin"]
START = dt.date(2020, 3, 1)


def _patients(n_patients: int, seed: int):
    rng = random.Random(f"{seed}-patients")
    for pid in range(1, n_patients + 1):
        age = None if rng.random() < 0.03 else rng.randint(1, 95)
        yield (pid, rng.choice(NAMES), age)


def _tests(n_rows: int, n_patients: int, seed: int):
    rng = random.Random(f"{seed}-tests")
    tid = 0
    while tid < n_rows:
        r = rng.random()
        pid = n_patients + rng.randint(1, 100) if r < 0.02 else rng.randint(1, n_patients)
        never_pos = rng.random() < 0.2
        k = rng.choice([1, 2, 2, 3, 3, 4, 5, 6, 8, 12])
        d = START + dt.timedelta(days=rng.randrange(900))
        state = "Negative"
        for _ in range(k):
            if tid >= n_rows:
                return
            tid += 1
            if rng.random() > 0.10:
                d += dt.timedelta(days=rng.choice([1, 2, 3, 3, 5, 7, 10, 14]))
            x = rng.random()
            if x < 0.15:
                result = "Inconclusive"
            elif never_pos:
                result = "Negative"
            elif state == "Negative":
                state = result = "Positive" if x < 0.65 else "Negative"
            else:
                state = result = "Negative" if x < 0.55 else "Positive"
            test_date = None if rng.random() < 0.01 else d
            yield (tid, pid, test_date, result)


def generate(n_rows: int, seed: int) -> dict:
    n_patients = max(3, n_rows // 4)
    return {
        "patients": _patients(n_patients, seed),
        "covid_tests": _tests(n_rows, n_patients, seed),
    }
