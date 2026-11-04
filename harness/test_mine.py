"""--mine: check the learner's my_answer.sql. Only collected when --mine is given.

    pytest -q harness -k 01-market-analysis-i --mine
"""
import pytest

from harness.runner import check_differential, check_edge
from harness.sqlsplit import is_blank


def _skip_if_blank(problem):
    if is_blank(problem.my_answer.read_text(encoding="utf-8")):
        pytest.skip(f"{problem.name}/my_answer.sql is empty - write your query there first")


def test_mine_edge(mysql_server, mine_edge_case):
    problem, edge, answer = mine_edge_case
    _skip_if_blank(problem)
    check_edge(problem, edge, answer)


def test_mine_differential(mysql_server, mine_problem):
    """Your answer vs the reference solution on random data - catches what the edge cases miss."""
    _skip_if_blank(mine_problem)
    if not mine_problem.solutions():
        pytest.skip("no reference solution yet")
    check_differential(mine_problem, [mine_problem.my_answer, mine_problem.optimal],
                       reference=mine_problem.optimal.stem)
