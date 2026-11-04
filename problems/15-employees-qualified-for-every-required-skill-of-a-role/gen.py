"""Random data for Employees Qualified for Every Required Skill of a Role.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of EmployeeSkills rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Skills = clamp(n_rows // 50, 20, 300), named 'skill_000' ... with Zipf-like popularity. Roles = clamp(n_rows // 30, 6, 40)
  and each role requires 2-6 distinct skills (the first one is drawn from the popular head, so roles overlap on skills).
- ~20% of employees are 'targeted': built to hold every skill of one random role (plus 0-3 extras), so there are always
  qualifying (role, employee) pairs. ~15% are 'near misses': a random role minus one required skill. The rest hold a random
  popularity-weighted handful of skills.
- ~10% of claims are repeated (exact duplicate rows). ~2% of a employee's claims are re-cased ('SKILL_007') and ~1% get a
  trailing space; those are different strings under the spec's exact-equality rule and must not match.
- Employees are produced in id order until n_rows claims exist (the last employee may be cut short).
"""
import bisect
import itertools
import random


def _sizes(n_rows: int):
    return max(20, min(300, n_rows // 50)), max(6, min(40, n_rows // 30))


def _skill(i: int) -> str:
    return f"skill_{i:03d}"


def _role_requirements(n_rows: int, seed: int):
    """Deterministic list of (role, [skills])."""
    n_skills, n_roles = _sizes(n_rows)
    rng = random.Random(f"{seed}-roles")
    cum = list(itertools.accumulate(1.0 / (r ** 0.8) for r in range(1, n_skills + 1)))
    roles = []
    for r in range(1, n_roles + 1):
        want = rng.randint(2, 6)
        picked = {bisect.bisect_left(cum, rng.random() * cum[-1]) for _ in range(want * 3)}
        skills = sorted(picked)[:want]
        while len(skills) < 2:
            skills = sorted(set(skills) | {rng.randrange(n_skills)})
        roles.append((f"role_{r:02d}", [_skill(i) for i in skills]))
    return roles


def _requirements(n_rows: int, seed: int):
    for role, skills in _role_requirements(n_rows, seed):
        for s in skills:
            yield (role, s)


def _claims(n_rows: int, seed: int):
    n_skills, _ = _sizes(n_rows)
    roles = _role_requirements(n_rows, seed)
    rng = random.Random(f"{seed}-employees")
    cum = list(itertools.accumulate(1.0 / (r ** 0.8) for r in range(1, n_skills + 1)))
    emitted, emp = 0, 0
    while emitted < n_rows:
        emp += 1
        r = rng.random()
        if r < 0.20:
            skills = list(rng.choice(roles)[1])
            skills += [_skill(rng.randrange(n_skills)) for _ in range(rng.randint(0, 3))]
        elif r < 0.35:
            skills = list(rng.choice(roles)[1])
            skills.pop(rng.randrange(len(skills)))
        else:
            skills = [_skill(bisect.bisect_left(cum, rng.random() * cum[-1])) for _ in range(rng.randint(1, 8))]
        rows = []
        for s in dict.fromkeys(skills):
            x = rng.random()
            shown = s.upper() if x < 0.02 else (s + " " if x < 0.03 else s)
            rows.append((emp, shown))
            while rng.random() < 0.10:
                rows.append((emp, shown))
        rng.shuffle(rows)
        for row in rows:
            if emitted >= n_rows:
                return
            emitted += 1
            yield row


def generate(n_rows: int, seed: int) -> dict:
    return {
        "RoleRequirements": _requirements(n_rows, seed),
        "EmployeeSkills": _claims(n_rows, seed),
    }
