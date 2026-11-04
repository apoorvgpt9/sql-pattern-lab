"""All solutions of a problem must agree on randomly generated data (seeds 1..5, 300 rows)."""
import pytest

from harness.runner import check_differential


def test_differential(mysql_server, solved_problem):
    sols = solved_problem.solutions()
    if len(sols) < 2:
        pytest.skip("needs at least two solutions to compare")
    check_differential(solved_problem, sols, reference=solved_problem.optimal.stem)
