"""Every solution must reproduce the hand-computed output of every edge dataset."""
from harness import db
from harness.runner import check_edge
from harness.spec import MAX_EDGE_ROWS_PER_TABLE


def test_edge_dataset_loads(mysql_server, edge_dataset):
    """The dataset itself is valid SQL and small enough to compute by hand."""
    problem, edge = edge_dataset
    with db.fresh_database() as conn:
        db.run_file(conn, problem.schema_sql)
        db.run_file(conn, problem.edge_sql(edge))
        counts = db.table_row_counts(conn)
    big = {t: n for t, n in counts.items() if n > MAX_EDGE_ROWS_PER_TABLE}
    assert not big, f"{problem.name}/{edge}: tables over {MAX_EDGE_ROWS_PER_TABLE} rows: {big}"


def test_edge(mysql_server, edge_case):
    problem, edge, solution = edge_case
    check_edge(problem, edge, solution)
