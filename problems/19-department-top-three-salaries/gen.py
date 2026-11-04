"""Random data for Department Top Three Salaries.

generate(n_rows, seed) -> {table: rows}; n_rows is the number of Employee rows.
Rows are yielded lazily so n_rows=1_000_000 streams without building lists.

Distributions chosen to exercise the logic:
- Departments = n_rows // 15 (at least 3), so many departments have fewer than ~10 people: a large
  share has fewer than 3 distinct salaries (everyone qualifies) and the rest cut people off.
  Department sizes are skewed (a few big ones). The top 5% of department ids never receive employees.
- Salaries are multiples of 1000 drawn from only 15 values, so ties are everywhere: ties at the top,
  ties exactly at the third distinct value, and big departments with many more than 3 rows in the output.
- ~2% of employees have departmentId NULL and ~2% a departmentId that is not in Department.
"""
import random

FIRST = ["Ann", "Bob", "Cy", "Di", "Eli", "Flo", "Gus", "Hal", "Ida", "Jon", "Kai", "Lea", "Max", "Nia", "Oto", "Pia"]
DEPT_NAMES = ["IT", "Sales", "HR", "Ops", "Legal", "Finance", "Support", "Research"]


def _n_depts(n_rows: int) -> int:
    return max(3, n_rows // 15)


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
        yield (eid, f"{rng.choice(FIRST)}{eid}", rng.randint(1, 15) * 1000, dept)


def generate(n_rows: int, seed: int) -> dict:
    n_depts = _n_depts(n_rows)
    return {
        "Department": _departments(n_depts, seed),
        "Employee": _employees(n_rows, n_depts, seed),
    }
