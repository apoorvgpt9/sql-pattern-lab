"""Random data for Most Common Course Pairs.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of course_completions rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic, not to look pretty:
- A catalog of 30 course ids. Ids 25..30 are second "editions" that reuse the names of ids 1..6, so
  pairs counted by NAME merge different course ids.
- Courses per user: 15% have 1-3, 25% have exactly 4 or 5, the rest 6-12. Users with exactly 5 courses are
  common, so the ">= 5" boundary is exercised by every seed.
- Users have a quality level that drives ratings (about 30% of users end up as top performers, and some
  sit exactly at average 4.0), so both rating and count thresholds filter real rows.
- Course choice favours low ids (popular courses) and each user mostly completes them in id order, with random
  swaps, so identical transitions repeat across users (counts well above 1) and reverse pairs also occur.
- Gaps between completions are 0-60 days; about 2% are 0, so same-date ties happen and the course_id tie-break matters.
- No NULLs: the spec says nulls are only the missing successor of each user's last course.
"""
import datetime as dt
import random

N_COURSES = 30
TOPICS = ["SQL", "Python", "Spark", "Airflow", "dbt", "Kafka", "Snowflake", "Docker", "Git", "Linux",
          "Statistics", "Modeling", "Testing", "Cloud", "Security", "Streaming", "Orchestration", "Pandas",
          "Warehousing", "Lakehouse", "APIs", "Scala", "Rust", "Observability"]
START = dt.date(2020, 1, 1)


def course_name(course_id: int) -> str:
    base = TOPICS[(course_id - 1) % len(TOPICS)]  # ids 25..30 wrap onto the names of ids 1..6
    return base


def _courses_per_user(rng: random.Random) -> int:
    r = rng.random()
    if r < 0.15:
        return rng.randint(1, 3)
    if r < 0.40:
        return rng.choice((4, 5))
    return rng.randint(6, 12)


def _rating(rng: random.Random, quality: float) -> int:
    return max(1, min(5, int(round(rng.gauss(quality, 0.9)))))


def _completions(n_rows: int, seed: int):
    rng = random.Random(f"{seed}-completions")
    emitted, user_id = 0, 0
    weights = [1.0 / (1 + i * 0.25) for i in range(N_COURSES)]  # popular courses first
    while emitted < n_rows:
        user_id += 1
        k = min(_courses_per_user(rng), n_rows - emitted, N_COURSES)
        quality = rng.choice((2.8, 3.6, 4.0, 4.3, 4.7))
        chosen = set()
        while len(chosen) < k:
            chosen.add(rng.choices(range(1, N_COURSES + 1), weights)[0])
        ordered = sorted(chosen)
        for _ in range(max(0, k // 3)):          # a few random swaps: mostly id order, not always
            i, j = rng.randrange(k), rng.randrange(k)
            ordered[i], ordered[j] = ordered[j], ordered[i]
        day = dt.timedelta(days=rng.randrange(400))
        for cid in ordered:
            yield (user_id, cid, course_name(cid), START + day, _rating(rng, quality))
            day += dt.timedelta(days=0 if rng.random() < 0.02 else rng.randint(1, 60))
        emitted += k


def generate(n_rows: int, seed: int) -> dict:
    return {"course_completions": _completions(n_rows, seed)}
