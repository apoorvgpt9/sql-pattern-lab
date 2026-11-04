"""Random data for Department Highest Salary.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Employee rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Departments = n_rows // 20 (at least 3). Department sizes are skewed: a few huge departments, a
  long tail of small ones. The top 5% of department ids never receive employees (empty departments).
- Salaries are multiples of 1000 drawn from only 25 values, so ties at the maximum, and ties just
  below it, occur in almost every department that has more than a handful of people.
- ~2% of employees have departmentId NULL and ~2% a departmentId that is not in Department.
- A few employees are paid 0, so the smallest possible maximum occurs.
"""
import random

FIRST = ["Ann", "Bob", "Cy", "Di", "Eli", "Flo", "Gus", "Hal", "Ida", "Jon", "Kai", "Lea", "Max", "Nia", "Oto", "Pia"]
DEPT_NAMES = ["IT", "Sales", "HR", "Ops", "Legal", "Finance", "Support", "Research"]


def _n_depts(n_rows: int) -> int:
    return max(3, n_rows // 20)


def _departments(n_depts: int, seed: int):
    for did in range(1, n_depts + 1):
        yield (did, f"{DEPT_NAMES[did % len(DEPT_NAMES)]}-{did}")


def _employees(n_rows: int, n_depts: int, seed: int):
    rng = random.Random(f"{seed}-employees")
    staffed = max(1, int(n_depts * 0.95))  # ids above this stay empty
    for eid in range(1, n_rows + 1):
        r = rng.random()
        if r < 0.02:
            dept = None
        elif r < 0.04:
            dept = n_depts + rng.randint(1, 50)  # no such department
        else:
            dept = int(staffed * rng.random() ** 2) + 1  # skew toward low ids
        salary = 0 if rng.random() < 0.005 else rng.randint(1, 25) * 1000
        yield (eid, f"{rng.choice(FIRST)}{eid}", salary, dept)


def generate(n_rows: int, seed: int) -> dict:
    n_depts = _n_depts(n_rows)
    return {
        "Department": _departments(n_depts, seed),
        "Employee": _employees(n_rows, n_depts, seed),
    }
